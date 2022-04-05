require 'time'

class SierraBatch
  attr_reader :size, :offset, :records, :process_statuses

  def initialize(record_response)
    @size = record_response.body["total"]
    @offset = record_response.body["start"]
    @records = record_response.body["entries"]
    @process_statuses = { success: 0, error: 0 }
    @retry_count = ENV["RETRY_COUNT"].to_i || 3
  end

  def encode_and_send_to_kinesis
    start_time = Time.now
    #Send individual records to $kinesis_client and log encoding errors
    @records.each do |record|
      sierra_record = SierraRecord.new(record)

      begin
        sierra_record.encode_and_send_to_kinesis
        # $logger.info("Sent record to kinesis stream record ##{record['id']}")
      rescue AvroError => e
        $logger.warn("Record (id# #{record['id']} failed avro validation", { status: e.message })
        @process_statuses[:error] += 1
        next
      end
    end
    #Make sure that records are not unprocessed if total amount is not 
    #divisible by $kinesis_client.batch_size. Any failed records are
    #saved in an instance variable on $kinesis_client
    $kinesis_client.push_records
    #Retry failed records as many times as configured (default 3)
    @retry_count.times { $kinesis_client.retry_failed_records }
    @process_statuses[:error] += $kinesis_client.failed_records.length
    @process_statuses[:success] += (@records.length - @process_statuses[:error])
    unless $kinesis_client.failed_records.empty?
      ids = $kinesis_client.failed_records.map{ |record| record[:id] }.join(", ")
      $logger.warn("#{$kinesis_client.failed_records.length} records failed to enter the kinesis stream, with ids: #{ids}")
    end
    logger.info("Records sent to kinesis in #{Time.now - start_time} seconds")
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
