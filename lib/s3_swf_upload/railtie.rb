require 's3_swf_upload'
require 'rails'

module S3SwfUpload
  class Railtie < Rails::Railtie
    
    generators do
      require "s3_swf_upload/railties/generators/uploader/uploader_generator"
    end
    
  end
end
