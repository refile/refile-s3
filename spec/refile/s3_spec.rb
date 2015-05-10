require "refile/spec_helper"
require "refile/s3"

WebMock.allow_net_connect!

config = YAML.load_file("s3.yml").map { |k, v| [k.to_sym, v] }.to_h

RSpec.describe Refile::S3 do
  let(:backend) { Refile::S3.new(max_size: 100, **config) }

  it_behaves_like :backend
end
