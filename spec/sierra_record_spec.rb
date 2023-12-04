require_relative '../lib/sierra_batch'
require_relative './spec_helper'

describe SierraBatch::SierraRecord do
    before(:each) {
        @mock_record = mock()
        @test_record = SierraBatch::SierraRecord.new @mock_record
    }

    describe '#send_to_kinesis' do
        it 'should send encoded record to kinesis' do
            $kinesis_client = mock()
            $kinesis_client.stubs(:<<).once

            @test_record.encode_and_send_to_kinesis
        end
    end
end