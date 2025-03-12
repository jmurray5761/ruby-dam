# frozen_string_literal: true

# Use this hook to configure devise mailer, warden hooks and so forth.
# Many of these configuration options can be set straight in your model.
ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick.analyzer = :image_processing

Rails.application.config.active_storage.analyzers = [ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick] 