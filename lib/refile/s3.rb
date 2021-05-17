require "aws-sdk-s3"
require "open-uri"
require "refile"
require "refile/s3/version"

module Refile

  # @api private
  class S3BackendError < StandardError; end

  # @api private
  class S3CredentialsError < S3BackendError
    def message
      "Credentials not found"
    end
  end

  # A refile backend which stores files in Amazon S3
  #
  # @example
  #   backend = Refile::Backend::S3.new(
  #     region: "sa-east-1",
  #     bucket: "my-bucket",
  #     prefix: "files"
  #   )
  #   file = backend.upload(StringIO.new("hello"))
  #   backend.read(file.id) # => "hello"
  class S3
    extend Refile::BackendMacros

    attr_reader :access_key_id, :max_size

    # Sets up an S3 backend
    #
    # @param [String] region            The AWS region to connect to
    # @param [String] bucket            The name of the bucket where files will be stored
    # @param [String] prefix            A prefix to add to all files. Prefixes on S3 are kind of like folders.
    # @param [Integer, nil] max_size    The maximum size of an uploaded file
    # @param [#hash] hasher             A hasher which is used to generate ids from files
    # @param [Hash] s3_options          Additional options to initialize S3 with
    # @see http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/Core/Configuration.html
    # @see http://docs.aws.amazon.com/AWSRubySDK/latest/AWS/S3.html
    def initialize(region:, bucket:, max_size: nil, prefix: nil, hasher: Refile::RandomHasher.new, **s3_options)
      @s3_options = { region: region }.merge s3_options
      @s3 = Aws::S3::Resource.new @s3_options
      credentials = @s3.client.config.credentials
      raise S3CredentialsError unless credentials
      @access_key_id = credentials.access_key_id rescue nil
      @bucket_name = bucket
      @bucket = @s3.bucket @bucket_name
      @hasher = hasher
      @prefix = prefix
      @max_size = max_size
    end

    # Upload a file into this backend
    #
    # @param [IO] uploadable      An uploadable IO-like object.
    # @return [Refile::File]      The uploaded file
    verify_uploadable def upload(uploadable)
      id = @hasher.hash(uploadable)

      if uploadable.is_a?(Refile::File) and uploadable.backend.is_a?(S3) and uploadable.backend.access_key_id == access_key_id
        object(id).copy_from(copy_source: [@bucket_name, uploadable.backend.object(uploadable.id).key].join("/"))
      else
        object(id).put(body: uploadable, content_length: uploadable.size)
      end

      Refile::File.new(self, id)
    end

    # Get a file from this backend.
    #
    # Note that this method will always return a {Refile::File} object, even
    # if a file with the given id does not exist in this backend. Use
    # {FileSystem#exists?} to check if the file actually exists.
    #
    # @param [String] id           The id of the file
    # @return [Refile::File]      The retrieved file
    verify_id def get(id)
      Refile::File.new(self, id)
    end

    # Delete a file from this backend
    #
    # @param [String] id           The id of the file
    # @return [void]
    verify_id def delete(id)
      object(id).delete
    end

    # Return an IO object for the uploaded file which can be used to read its
    # content.
    #
    # @param [String] id           The id of the file
    # @return [IO]                An IO object containing the file contents
    verify_id def open(id)
      Kernel.open(object(id).presigned_url(:get))
    end

    # Return the entire contents of the uploaded file as a String.
    #
    # @param [String] id           The id of the file
    # @return [String]             The file's contents
    verify_id def read(id)
      object(id).get.body.read
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    # Return the size in bytes of the uploaded file.
    #
    # @param [String] id           The id of the file
    # @return [Integer]           The file's size
    verify_id def size(id)
      object(id).get.content_length
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    # Return whether the file with the given id exists in this backend.
    #
    # @param [String] id           The id of the file
    # @return [Boolean]
    verify_id def exists?(id)
      object(id).exists?
    end

    # Remove all files in this backend. You must confirm the deletion by
    # passing the symbol `:confirm` as an argument to this method.
    #
    # @example
    #   backend.clear!(:confirm)
    # @raise [Refile::Confirm]     Unless the `:confirm` symbol has been passed.
    # @param [:confirm] confirm    Pass the symbol `:confirm` to confirm deletion.
    # @return [void]
    def clear!(confirm = nil)
      raise Refile::Confirm unless confirm == :confirm
      @bucket.objects(prefix: @prefix).batch_delete!
    end

    # Return a presign signature which can be used to upload a file into this
    # backend directly.
    #
    # @return [Refile::Signature]
    def presign
      id = RandomHasher.new.hash
      signature = @bucket.presigned_post(key: [*@prefix, id].join("/"))
      signature.content_length_range(0..@max_size) if @max_size
      Signature.new(as: "file", id: id, url: signature.url.to_s, fields: signature.fields)
    end

    verify_id def object(id)
      @bucket.object([*@prefix, id].join("/"))
    end
  end
end
