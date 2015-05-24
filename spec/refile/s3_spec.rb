require "refile/spec_helper"
require "refile/s3"

WebMock.allow_net_connect!

s3_config = YAML.load_file("s3.yml").map { |k, v| [k.to_sym, v] }.to_h

RSpec.describe Refile::S3 do
  let(:config) { s3_config }
  let(:backend) { Refile::S3.new(max_size: 100, **config) }

  it_behaves_like :backend

  describe '@s3_options' do
    let(:value) { backend.instance_variable_get(:@s3_options) }

    it 'is initialized' do
      %i(access_key_id secret_access_key region).each do |attribute|
        expect(value[attribute]).to eq(config[attribute])
      end
    end
  end

  %i(s3_object_operation_options s3_presigned_post_options).each do |option|
    describe "@#{option}" do
      let(:additional_config) do
        { "#{option}".to_sym => { server_side_encryption: 'aes256' } }
      end

      let(:config) { additional_config.merge s3_config }
      let(:value) { backend.send(:instance_variable_get, "@#{option}") }

      it 'is initialized' do
        expect(value[:server_side_encryption]).to eq('aes256')
        expect(backend.instance_variable_get(:@s3_options)).not_to have_key(option)
      end
    end

    describe ".#{option}" do
      let(:additional_config) do
        { "#{option}".to_sym => { server_side_encryption: 'aes256' } }
      end

      let(:config) { additional_config.merge s3_config }

      it 'is merges provided options' do
        expect(backend.send(option, { server_side_encryption: 'aws:kms' })[:server_side_encryption]).to eq('aws:kms')
      end
    end
  end
end
