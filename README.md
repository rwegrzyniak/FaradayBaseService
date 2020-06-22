# FaradayBaseService
## Usage
Implement own service with `call()` method, call method have to `return true` if action was successful.
Error handling and response parsing(if you set response via `self.resp = response`) is handled by base class.
## Examples
    Service.call(data) do |on|
      on.failure do |service|
        Rails.logger.error service.error
      end
      on.success { |result| some_var_from_json_response = result.json_field }
    end
