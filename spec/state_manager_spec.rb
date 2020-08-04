require_relative '../lib/state_manager'
require_relative './spec_helper'

describe StateManager do
    before(:each) {
        @s3_stub = mock()
        Aws::S3::Client.stubs(:new).returns(@s3_stub)
        @test_manager = StateManager.new
    }

    after(:each) {
        Aws::S3::Client.unstub(:new)
    }

    describe '#fetch_current_state' do
        it 'should set time and offset stored in S3 if successfully fetched' do
            mock_resp = mock()
            mock_resp.stubs(:code).returns('200')
            mock_resp.stubs(:body).returns(JSON.dump({
                :record_type => 'test',
                :last_execution_time => 'last_time',
                :last_execution_offset => 'last_offset'
            }))

            Net::HTTP.stubs(:get_response).returns(mock_resp)

            @test_manager.fetch_current_state

            expect(@test_manager.start_time).to eq('last_time')
            expect(@test_manager.start_offset).to eq('last_offset')
        end

        it 'should raise a S3Error if the status code is not 200' do
            mock_resp = mock()
            mock_resp.stubs(:code).returns('400')
            mock_resp.stubs(:body).returns('Test Error Message')

            Net::HTTP.stubs(:get_response).returns(mock_resp)

            expect { @test_manager.fetch_current_state }.to raise_error(S3Error, 'Unable to load state from S3 with error Test Error Message')
        end

        it 'should raise a S3Error if the HTTP request fails' do
            Net::HTTP.stubs(:get_response).raises(Exception.new)

            expect { @test_manager.fetch_current_state }.to raise_error(S3Error, 'Could not load file from S3')
        end

        it 'should raise a S3Error if the RECORD_TYPE does not match environment variable' do
            mock_resp = mock()
            mock_resp.stubs(:code).returns('200')
            mock_resp.stubs(:body).returns(JSON.dump({
                :record_type => 'other',
                :last_execution_time => 'last_time',
                :last_execution_offset => 'last_offset'
            }))

            Net::HTTP.stubs(:get_response).returns(mock_resp)

            expect { @test_manager.fetch_current_state }.to raise_error(S3Error, 'Loaded JSON file for incorrect record type')
        end
    end

    describe '#set_current_state' do
        it 'should PUT object in S3 and update instance variables on success' do
            @s3_stub.stubs(:put_object)
                .with({
                    :body => JSON.dump({:last_execution_time => 'current_time', :last_execution_offset => 'current_offset', :record_type => 'test'}),
                    :bucket => 'test_bucket',
                    :key => 'sierratest_poller_status.json',
                    :acl => 'public-read'
                })
            
            @test_manager.set_current_state('current_time', 'current_offset')

            expect(@test_manager.start_time).to eq('current_time')
            expect(@test_manager.start_offset).to eq('current_offset')
        end

        it 'should raise a S3Error if the PUT operation fails' do
            @s3_stub.stubs(:put_object).raises(Exception.new)

            expect { @test_manager.set_current_state('current_time', 'current_offest') }.to raise_error(S3Error, 'Failed to store most recent state record in S3')
        end
    end
end