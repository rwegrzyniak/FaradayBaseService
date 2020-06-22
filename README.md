# FaradayBaseService
## Usage
Implement own service with `call()` method, `call()` method have to `return true` if action was successful.
Error handling and response parsing(if you set response via `self.resp`) is handled by base class.
If you are implementing your service under namespace you can use rails config feature and set `base_url` under `Rails.configuration.your_namespace.base_url` or you can override `base_url()` method.
Also you can define own FaradayClient options in hash returned from `client_options()` method 
## Examples
Implementing own service

    class CreateSomeResourceInExternalApi < BaseService
      def initialize(app_resource)
        @app_resource = app_resource
      end

      def call
        self.resp = @conn.post("some_path/#{@app_resource.parent.id}/new_resource")
        return true if resp.status == 201
      end
    end
Usage of service

    CreateSomeResourceInExternalApi.call(data) do |on|
      on.failure do |result|
        Rails.logger.error result.error
      end
      on.success { |result| some_var_from_json_response = result.json_field }
    end
