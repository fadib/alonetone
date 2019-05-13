# frozen_string_literal: true

# Helper class to translate variant names to Active Storage variants
# and process them.
class ImageVariant
  include ActiveSupport::Benchmarkable
  delegate :logger, to: Rails

  S3_PUBLIC_ACL = 'public-read'
  VARIANTS = {
    small: {
      resize_to_fill: [50, 50],
      saver: { quality: 68, optimize_coding: true, strip: true }
    },
    large: {
      resize_to_fill: [125, 125],
      saver: { quality: 68, optimize_coding: true, strip: true }
    },
    album: {
      resize_to_fill: [200, 200],
      saver: { quality: 68, optimize_coding: true, strip: true }
    },
    original: {
      resize_to_fill: [800, 800],
      saver: { quality: 68, optimize_coding: true, strip: true }
    },
    greenfield: {
      resize_to_fill: [1500, 1500],
      saver: { quality: 68, optimize_coding: true, strip: true }
    },
    hq: {
      resize_to_fill: [3000, 3000],
      saver: { quality: 68, optimize_coding: true, strip: true }
    }
  }.freeze

  attr_reader :attachment
  attr_reader :variant_name

  def initialize(attachment, variant:)
    ImageVariant.verify(variant)

    @attachment = attachment
    @variant_name = variant
  end

  def process
    logger.tagged('ImageVariant') do
      to_active_storage_variant.processed
    end
  end

  def variant_options
    ImageVariant.variant_options(variant_name)
  end

  def to_active_storage_variant
    attachment.variant(**variant_options)
  end

  # Returns an Active Storage variant for a named variant.
  def self.variant(attachment, variant:)
    new(attachment, variant: variant).to_active_storage_variant
  end

  # Processes all variants for an attachment.
  def self.process(attachment)
    VARIANTS.keys.map do |variant_name|
      new(attachment, variant: variant_name).process
    end
  end

  # Fit a variant inside these dimensions (width x height) to generate the variant.
  def self.variant_options(variant_name)
    VARIANTS[variant_name.to_sym]
  end

  # Raises ArgumentError with explanation when the variant name does not exist.
  def self.verify(variant_name)
    unless ImageVariant::VARIANTS.key?(variant_name.to_sym)
      raise(
        ArgumentError,
        "Unknown variant: `#{variant_name.inspect}', please use: #{variants_as_sentence}"
      )
    end
  end

  # Returns an English sentence with all the variant options.
  def self.variants_as_sentence
    VARIANTS.keys.to_sentence(
      two_words_connector: ' or ',
      last_word_connector: ', or ',
      locale: :en
    )
  end
end
