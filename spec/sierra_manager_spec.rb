require_relative '../lib/sierra_manager'
require_relative './spec_helper'

describe SierraManager do
    before(:each) {
        mock_state = mock()
        mock_state.stubs(:start_time).returns('start_time')
        mock_state.stubs(:start_offset).returns(0)
        sierra_stub = mock()
        NYPLRubyUtil::SierraApiClient.stubs(:new).returns(sierra_stub)

        $logger = mock()
        $logger.stubs(:info)
        $logger.stubs(:debug)
        $logger.stubs(:error)
        $kms_client = mock()
        $kms_client.stubs(:decrypt).returns(0, 0)

        @test_manager = SierraManager.new(mock_state)
    }

    after(:each) {
        NYPLRubyUtil::SierraApiClient.unstub(:new)
        $logger.unstub()
    }

    describe '#fetch_updated_records' do
        it 'should process batches until process is set to false' do
            DateTime.stubs(:now).returns('current_time')

            # Skip kinesis processing for this test:
            @test_manager.stubs(:send_results_to_kinesis)

            @test_manager.stubs(:_fetch_record_batch).returns('result1', 'result2')
            @test_manager.stubs(:_parse_result_batch).with() { |value|
                if value == 'result2'
                    @test_manager.processing = false
                end

                true
            }

            @test_manager.fetch_updated_records
            expect(@test_manager.processing).to eq(false)
            expect(@test_manager.current_time).to eq('current_time')
        end

        it 'should send previously fetched batch to kinesis on each run' do
            DateTime.stubs(:now).returns('current_time')

            # Expect SierraBatch.encode_and_send_to_kinesis called twice
            mock_batch = mock()
            mock_batch.stubs(:encode_and_send_to_kinesis).twice
            mock_batch.stubs(:has_results?).twice.returns(true)
            mock_batch.stubs(:process_statuses).returns({ success: 0, error: 0 })

            # Expect two SierraBatch instances created around the two results:
            SierraBatch.stubs(:new).with('result1').returns(mock_batch)
            SierraBatch.stubs(:new).with('result2').returns(mock_batch)

            @test_manager.stubs(:_fetch_record_batch).returns('result1', 'result2')
            @test_manager.stubs(:_parse_result_batch).with() do |value|
                if value == 'result2'
                    @test_manager.processing = false
                end
                true
            end

            expect(@test_manager.processing).to eq(true)
            @test_manager.fetch_updated_records
            expect(@test_manager.processing).to eq(false)
        end
    end

    describe '#validate_processing' do
        it 'should not raise an error if fewer than 1% records errored' do
            @test_manager.records_processed = { :success => 1000, :error => 1 }

            expect { @test_manager.validate_processing }.not_to raise_error
        end

        it 'should raise an error if more than 1% records errored' do
            @test_manager.records_processed = { :success => 1000, :error => 25 }

            expect { @test_manager.validate_processing }.to raise_error(SierraError, 'Records processing errors exceeded 1% threshold!')
        end
    end

    describe '#_fetch_record_batch' do
        it 'should query the Sierra API with the current querry settings' do
            @test_manager.stubs(:_query_sierra_api)
                .with([['fields', 'test_fields'], ['offset', 0], ['updatedDate', '[start_time,]'], ['limit', 100]])

            @test_manager.send(:_fetch_record_batch)
        end
    end

    describe '#_fetch_record_batch when UPDATE_TYPE = \'delete\'' do
        before(:each) do
          ENV['UPDATE_TYPE'] = 'delete'
        end

        it 'should query the Sierra API with the current querry settings' do
            @test_manager.stubs(:_query_sierra_api)
                .with([['fields', 'test_fields'], ['offset', 0], ['deletedDate', '[start_time,]'], ['limit', 100]])

            @test_manager.send(:_fetch_record_batch)
        end

        after(:each) do
          ENV['UPDATE_TYPE'] = nil
        end
    end

    describe '#_parse_result_batch' do
        it 'should invoke the error procesor if the Sierra API client returns an error object' do
            test_results = mock()
            test_results.stubs(:error?).returns(true)
            @test_manager.stubs(:_process_error).with(test_results)
            @test_manager.stubs(:_process_batch).never

            @test_manager.send(:_parse_result_batch, test_results)
        end

        it 'should invoke the batch procesor if the Sierra API client returns a standard object' do
            test_results = mock()
            test_results.stubs(:error?).returns(false)
            @test_manager.stubs(:_process_error).never
            @test_manager.stubs(:_process_batch).with(test_results)

            @test_manager.send(:_parse_result_batch, test_results)
        end
    end

    describe '#_query_sierra_api' do
        it 'should return a result object on success' do
            @test_manager.sierra_client.stubs(:get)
                .with('/v0/test?test=params')
                .returns(true)

            result = @test_manager.send(:_query_sierra_api, [['test', 'params']])
            expect(result).to eq(true)
        end

        it 'should raise a SierraError if the client raises an error' do
            @test_manager.sierra_client.stubs(:get)
                .with('/v0/test?test=params')
                .raises(Exception.new)

            expect { @test_manager.send(:_query_sierra_api, [['test', 'params']]) }.to raise_error(SierraError, 'Received error from Sierra API. Review logs')
        end
    end

    describe '#_process_batch' do
        current_time = DateTime.now

        before(:each) do
          @test_manager.instance_variable_set(:@current_time, current_time)
        end

        it 'should reset state if batch is less than max size' do
            mock_batch = mock()
            mock_batch.stubs(:size).returns(49).once

            SierraBatch.stubs(:new).returns(mock_batch)

            @test_manager.state.stubs(:set_current_state).with(current_time.to_s, 0).once

            @test_manager.send(:_process_batch, [])

            expect(@test_manager.processing).to eq(false)
        end

        it 'should set state for max size if batch matches max size' do
            mock_batch = mock()
            mock_batch.stubs(:size).returns(100).once

            SierraBatch.stubs(:new).returns(mock_batch)

            @test_manager.state.stubs(:set_current_state).with('start_time', 100).once

            @test_manager.send(:_process_batch, [])

            expect(@test_manager.processing).to eq(true)
        end
    end

    describe '#_process_batch when UPDATE_TYPE is \'delete\'' do
      current_time = DateTime.now

      before(:each) do
        @test_manager.instance_variable_set(:@current_time, current_time)
        ENV['UPDATE_TYPE'] = 'delete'
      end

      it 'should reset state if batch is less than max size' do
          mock_batch = mock()
          mock_batch.stubs(:size).returns(49).once

          SierraBatch.stubs(:new).returns(mock_batch)

          @test_manager.state.stubs(:set_current_state).with(current_time.to_date.to_s, 0).once

          @test_manager.send(:_process_batch, [])

          expect(@test_manager.processing).to eq(false)
      end

      it 'should set state for max size if batch matches max size' do
          mock_batch = mock()
          mock_batch.stubs(:size).returns(100).once

          SierraBatch.stubs(:new).returns(mock_batch)

          @test_manager.state.stubs(:set_current_state).with('start_time', 100).once

          @test_manager.send(:_process_batch, [])

          expect(@test_manager.processing).to eq(true)
      end

      after(:each) do
        ENV['UPDATE_TYPE'] = nil
      end
    end

    describe '#_process_error' do
        it 'should treat a 404 error as an empty result and end processing records' do
            mock_results = mock()
            mock_results.stubs(:code).returns(404).once

            @test_manager.state.stubs(:set_current_state).with(nil, 0)

            @test_manager.send(:_process_error, mock_results)
            expect(@test_manager.processing).to eq(false)
        end

        it 'should treat all other errors as true errors and raise a SierraError' do
            mock_results = mock()
            mock_results.stubs(:code).returns(500).twice
            mock_results.stubs(:body).returns('Test Error Message')

            @test_manager.state.stubs(:set_current_state).never

            expect { @test_manager.send(:_process_error, mock_results) }.to raise_error(SierraError, 'Received unexpected 500 from Sierra API')
            expect(@test_manager.processing).to eq(true)
        end
    end

    describe '#_update_processing_counts' do
        it 'should increment processing counts from most recent batch' do
            @test_manager.send(:_update_processing_counts, { :success => 49, :error => 1 })

            expect(@test_manager.records_processed[:success]).to eq(49)
            expect(@test_manager.records_processed[:error]).to eq(1)

            @test_manager.send(:_update_processing_counts, { :success => 40, :error => 10 })

            expect(@test_manager.records_processed[:success]).to eq(89)
            expect(@test_manager.records_processed[:error]).to eq(11)
        end
    end
end
