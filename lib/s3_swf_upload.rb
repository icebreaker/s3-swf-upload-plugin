require 'patch/integer'
require 's3_swf_upload/signature'

module S3SwfUpload
  # Rails 3 Railties!
  # https://gist.github.com/af7e572c2dc973add221
  require 's3_swf_upload/railtie' if defined?(Rails)
end
