require 'base64'
class S3UploadsController < ApplicationController
  include S3SwfUpload::Signature
  
  def index
    bucket          = ''
    access_key_id   = ''
    acl             = ''
    secret_key      = ''
    key             = File.join('cache', params[:key])
    content_type    = params[:content_type]
    https           = 'false'
    expiration_date = 3.hours.from_now.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')

    policy = Base64.encode64(
"{
    'expiration': '#{expiration_date}',
    'conditions': [
        {'bucket': '#{bucket}'},
        {'key': '#{key}'},
        {'acl': '#{acl}'},
        {'Content-Type': '#{content_type}'},
        {'Content-Disposition': 'attachment'},
        ['starts-with', '$Filename', ''],
        ['eq', '$success_action_status', '201']
    ]
}").gsub(/\n|\r/, '')

    signature = b64_hmac_sha1(secret_key, policy)

    respond_to do |format|
      format.xml {
        render :xml => {
          :policy          => policy,
          :signature       => signature,
          :bucket          => bucket,
          :accesskeyid     => access_key_id,
          :acl             => acl,
          :expirationdate  => expiration_date,
          :https           => https,
          :key             => key
        }.to_xml
      }
    end
  end
end
