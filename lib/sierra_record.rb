
class SierraBatch
    attr_reader :size, :offset, :records

    def initialize record_response
        @size = record_response.body['total']
        @offset = record_response.body['start']
        @records = record_response.body['entries']
        @process_statuses = { :success => 0, :error => 0 }
    end

    def encode_and_send_to_kinesis
        @records.each { |record| 
            sierra_record = SierraRecord.new record
            begin
                sierra_record.encode
                $logger.info "Encoded record ##{record['id']}"
            rescue AvroError => e
                $logger.warning "Record (id# #{record['id']} failed avro validation", { :status => e.message }
                @process_statuses[:error] += 1
                next
            end

            begin
                sierra_record.send_to_kinesis
                $logger.info "Sent record to kinesis stream record ##{record['id']}"
            rescue Exception => e
                $logger.warning "Record (id# #{record['id']} failed to write to kinesis", { :status => e.message }
                @process_statuses[:error] += 1
                next
            end

            $logger.info "Successfully processed Record# #{record['id']}"
            @process_statuses[:success] += 1
        }
    end

    class SierraRecord
        attr_reader :record, :decoded_record
        def initialize record
            @record = record
            @encoded_record = nil
        end

        def encode 
            @encoded_record = $avro_client.encode @record
        end

        def send_to_kinesis
            $kinesis_client << @encoded_record
        end
    end
end