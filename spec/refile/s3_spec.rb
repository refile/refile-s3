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

    context 'given additional configuration options' do
      let(:config) { { server_side_encryption: 'aes256' }.merge s3_config }

      it 'is initialized' do
        expect(value[:server_side_encryption]).to eq('aes256')
      end
    end
  end

  describe '.s3_options_for' do
    let(:config) do
      {
        access_key_id: 'xyz',
        secret_access_key: 'abcd1234',
        region: 'sa-east-1',
        bucket: 'my-bucket',
        server_side_encryption: 'aes256',
        storage_class: 'STANDARD'
      }
    end
    let(:options) { {} }
    let(:value) { backend.s3_options_for key, options }

    describe 'given operation' do
      context 'client' do
        let(:key) { :client }

        it 'returns valid options' do
          expect(value).to eq(
            access_key_id: 'xyz',
            secret_access_key: 'abcd1234',
            region: 'sa-east-1'
          )
        end
      end

      context 'copy_from' do
        let(:key) { :copy_from }
        let(:options) { { copy_source: 'xyz' } }

        it 'returns valid options' do
          expect(value).to eq(
            copy_source: 'xyz',
            server_side_encryption: 'aes256',
            storage_class: 'STANDARD'
          )
        end
      end

      context 'presigned_post' do
        let(:key) { :presigned_post }
        let(:options) { { key: 'xyz' } }

        it 'returns valid options' do
          expect(value).to eq(
            key: 'xyz',
            server_side_encryption: 'aes256',
            storage_class: 'STANDARD'
          )
        end
      end

      context 'put' do
        let(:key) { :put }
        let(:options) { { body: 'xyz', content_length: 3 } }

        it 'returns valid options' do
          expect(value).to eq(
            body: 'xyz',
            content_length: 3,
            server_side_encryption: 'aes256',
            storage_class: 'STANDARD'
          )
        end
      end
    end

    context 'given an invalid operation' do
      let(:key) { :invalid }

      it 'raises an error' do
        expect { value }.to raise_error(KeyError)
      end
    end
  end
end
