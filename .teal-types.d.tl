global record cjson
   encode: function(table): string
   decode: function(string): table
end

global record socket_http
   request: function(table): any, number
end

global record ltn12
   source: record
      string: function(string): any
   end
   sink: record
      table: function({any}): any
   end
end