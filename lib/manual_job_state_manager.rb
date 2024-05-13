class ManualJobStateManager
    def initialize(event)
        @event = event
        @offset = @event['start_offset']
    end

    def start_time
        @event['start_time']
    end

    def end_time
        @event['end_time']
    end

    def start_offset
      @offset
    end

    def set_current_state(execution_time, execution_offset)
      @offset = execution_offset
    end
end
