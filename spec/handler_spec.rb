require_relative '../app'
require_relative './spec_helper'


describe 'handler' do
    describe '#init' do
        before(:each) {
            @kms_mock = mock()
            @kms_mock.stubs(:decrypt)
            NYPLRubyUtil::KmsClient.stubs(:new).returns(@kms_mock)
            @avro_mock = mock()
            NYPLRubyUtil::NYPLAvro.stubs(:by_name).returns(@avro_mock)
            @kinesis_mock = mock()
            NYPLRubyUtil::KinesisClient.stubs(:new).returns(@kinesis_mock)
        }

        after(:each) {
            @kms_mock.unstub(:decrypt)
        }

        it "should invoke clients and logger from the ruby utils gem" do
            init

            expect($kms_client).to eq(@kms_mock)
            expect($avro_client).to eq(@avro_mock)
            expect($kinesis_client).to eq(@kinesis_mock)
        end
     end

    describe '#handle_event' do
        it "should invoke the StateManager and Sierra manager to process records" do
            state_stub = mock()
            StateManager.stubs(:new).returns(state_stub)
            state_stub.expects(:fetch_current_state)
            
            sierra_stub = mock()
            SierraManager.stubs(:new).returns(sierra_stub)
            sierra_stub.expects(:fetch_updated_records)
            sierra_stub.expects(:validate_processing)

            self.stubs(:init).once

            handle_event(event: {}, context: {})
        end
    end
end