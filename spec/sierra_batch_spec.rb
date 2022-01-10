require_relative "../lib/sierra_record"
require_relative "./spec_helper"

describe SierraBatch do
  before(:each) do
    mock_response = mock
    mock_response.stubs(:body).returns({
      "total" => 50,
      "start" => 0,
      "entries" => (1..50).to_a.map { |x| { "id" => x } }.compact
    })
    @test_batch = SierraBatch.new(mock_response)
  end

  describe "#encode_and_send_to_kinesis" do
    it "should process all records successfully and increment status" do
      $kinesis_client = mock
      mock_record = mock
      mock_record.stubs(:encode_and_send_to_kinesis).times(50)
      SierraBatch::SierraRecord.stubs(:new).returns(mock_record).times(50)

      @test_batch.encode_and_send_to_kinesis
      $kinesis_client.stubs(:push_records).once

      expect(@test_batch.process_statuses[:success]).to(eq(50))
      expect(@test_batch.process_statuses[:error]).to(eq(0))
    end

    it "should increment errors if unable to encode records via avro" do
      mock_record = mock
      mock_record.stubs(:encode_and_send_to_kinesis).raises(AvroError).times(50)
      SierraBatch::SierraRecord.stubs(:new).returns(mock_record).times(50)

      @test_batch.encode_and_send_to_kinesis

      expect(@test_batch.process_statuses[:error]).to(eq(50))
      expect(@test_batch.process_statuses[:success]).to(eq(0))
    end

    it "should increment errors if unable to send records to kinesis stream" do
      mock_record = mock
      mock_record.stubs(:encode_and_send_to_kinesis).raises(NYPLError).times(50)
      SierraBatch::SierraRecord.stubs(:new).returns(mock_record).times(50)

      @test_batch.encode_and_send_to_kinesis

      expect(@test_batch.process_statuses[:error]).to(eq(50))
      expect(@test_batch.process_statuses[:success]).to(eq(0))
    end
  end
end
