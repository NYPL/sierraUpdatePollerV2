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
    $kinesis_client = mock
    @failed_records = mock
    $kinesis_client.stubs(:push_records)
    $kinesis_client.stubs(:retry_failed_records)
    $kinesis_client.stubs(:failed_records).returns([])
    $kinesis_client.stubs(:<<)
  end

  describe "#encode_and_send_to_kinesis" do
    it "should process all records successfully and increment status" do
      
      mock_record = mock
      mock_record.stubs(:encode_and_send_to_kinesis).times(50)
      SierraBatch::SierraRecord.stubs(:new).returns(mock_record).times(50)

      @test_batch.encode_and_send_to_kinesis

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


    it "should retry failed records the configured number of times" do
      mock_record = mock
      mock_record.stubs(:encode_and_send_to_kinesis)

      $kinesis_client.expects(:retry_failed_records).at_most(3)

      @test_batch.encode_and_send_to_kinesis
      $kinesis_client.expects(:retry_failed_records).at_most(3)
    end

    it "should increment errors if there are failed records after retrying" do
      $kinesis_client.stubs(:failed_records).returns([{ id: '1' }, { id: '2' }, { id: '3' }])

      @test_batch.encode_and_send_to_kinesis

      expect(@test_batch.process_statuses[:error]).to eql(3)
    end

    it "should call push_records after looping through records" do
      $kinesis_client = mock
      $kinesis_client.stubs(:retry_failed_records)
      $kinesis_client.stubs(:failed_records).returns([])
      $kinesis_client.stubs(:<<)
      $kinesis_client.stubs(:push_records).once

      @test_batch.encode_and_send_to_kinesis
    end

    it "should warn with a message including number of records and record ids of failed records" do
      $kinesis_client.stubs(:failed_records).returns([{ id: '1' }, { id: '2' }, { id: '3' }])
      @test_batch.encode_and_send_to_kinesis
      $logger.stubs(:warn).with("3 records failed to enter the kinesis stream, with ids: 1, 2, 3")
    end
  end
end
