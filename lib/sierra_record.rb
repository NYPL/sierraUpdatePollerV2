class SierraBatch
  attr_reader :size, :offset, :records, :process_statuses

  def initialize(record_response)
    @size = record_response.body["total"]
    @offset = record_response.body["start"]
    @records = record_response.body["entries"]
    @process_statuses = { success: 0, error: 0 }
  end

  def encode_and_send_to_kinesis
    @records.each do |record|
      sierra_record = SierraRecord.new record

      begin
        sierra_record.encode_and_send_to_kinesis
        $logger.info "Sent record to kinesis stream record ##{record['id']}"
      rescue AvroError => e
        $logger.warn "Record (id# #{record['id']} failed avro validation", { status: e.message }
        @process_statuses[:error] += 1
        next
      rescue NYPLError => e
        $logger.warn "Record (id# #{record['id']} failed to write to kinesis", { status: e.message }
        @process_statuses[:error] += 1
        next
      end

      $logger.info "Successfully processed Record# #{record['id']}"
      @process_statuses[:success] += 1
    end
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
