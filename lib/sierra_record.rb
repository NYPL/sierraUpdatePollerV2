class SierraBatch
  attr_reader :size, :offset, :records, :process_statuses

  def initialize(record_response)
    @size = record_response.body["total"]
    @offset = record_response.body["start"]
    @records = record_response.body["entries"]
    @process_statuses = { success: 0, error: 0 }
    @retry_count = ENV["RETRY_COUNT"]
  end

  def encode_and_send_to_kinesis
    @records.each do |record|
      sierra_record = SierraRecord.new(record)

      begin
        sierra_record.encode_and_send_to_kinesis
        $logger.info("Sent record to kinesis stream record ##{record['id']}")
      rescue AvroError => e
        $logger.warn("Record (id# #{record['id']} failed avro validation", { status: e.message })
        @process_statuses[:error] += 1
        next
      end
    end

    $kinesis_client.push_records
    @retry_count.times { $kinesis_client.retry_failed_records }
    @process_statuses[:error] = $kinesis_client.failed_records.length

    $logger.warn("#{remaining_failed_records.length} records failed to enter the kinesis stream:" +
    remainging_failed_records.each { |record| "record with bibId #{record.bibIds} \n" })
  end
  

  class SierraRecord
    attr_reader :record, :encoded_record

    def initialize(record)
      @record = record
    end

    def encode_and_send_to_kinesis
      $kinesis_client << @record
    end
  end
end
