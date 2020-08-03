require_relative '../lib/sierra_record'
require_relative './spec_helper'

describe SierraBatch::SierraRecord do
    before(:each) {
        @mock_record = mock()
        @test_record = SierraBatch::SierraRecord.new @mock_record
    }

    describe '#encode' do
        it 'should set an encoded record from avro' do
            $avro_client = mock()
            $avro_client.stubs(:encode).once.with(@mock_record, base64=false).returns('avro_record')
            
            @test_record.encode
            expect(@test_record.encoded_record).to eq('avro_record')
        end
    end

    describe '#send_to_kinesis' do
        it 'should send encoded record to kinesis' do
            $kinesis_client = mock()
            $kinesis_client.stubs(:<<).once

            @test_record.send_to_kinesis
        end
    end
end