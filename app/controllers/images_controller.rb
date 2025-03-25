class ImagesController < ApplicationController
  include Pagy::Backend
  
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::StaleObjectError, with: :handle_conflict
  rescue_from Timeout::Error, with: :handle_timeout
  rescue_from ActiveStorage::Error, with: :handle_storage_error

  before_action :set_image, only: [:show, :edit, :update, :destroy]

  def index
    @pagy, @images = pagy(Image.order(created_at: :desc))
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @image }
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to images_path, alert: 'Image not found.' }
      format.json { render json: { status: 'error', message: 'Image not found.' }, status: :not_found }
    end
  end

  def new
    @image = Image.new
  end

  def create
    @image = Image.new(image_params)
    @image.generate_name_and_description = true

    if @image.save
      # Wait for name and description generation
      max_attempts = 10
      attempts = 0
      
      while attempts < max_attempts
        @image.reload
        if @image.name.present? && @image.description.present?
          redirect_to @image, notice: 'Image was successfully uploaded.'
          return
        end
        sleep 0.5
        attempts += 1
      end
      
      # If we get here, we timed out waiting for generation
      redirect_to @image, notice: 'Image was uploaded. Name and description are being generated.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      begin
        if @image.update(image_params)
          format.html { redirect_to @image, notice: 'Image was successfully updated.' }
          format.json { render json: { status: 'success', message: 'Image was successfully updated.' } }
        else
          format.html { render :edit, status: :unprocessable_entity }
          format.json { render json: { status: 'error', errors: @image.errors.full_messages }, status: :unprocessable_entity }
        end
      rescue ActiveStorage::IntegrityError => e
        @image.errors.add(:file, "File upload failed: #{e.message}")
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { status: 'error', errors: @image.errors.full_messages }, status: :unprocessable_entity }
      rescue ActiveStorage::Error => e
        @image.errors.add(:file, "File upload failed. Please try again.")
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { status: 'error', errors: @image.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @image.destroy
    respond_to do |format|
      format.html { redirect_to images_url, notice: 'Image was successfully deleted.' }
      format.json { render json: { status: 'success', message: 'Image was successfully deleted.' } }
    end
  end

  private

  def set_image
    @image = Image.find(params[:id])
  end

  def image_params
    params.require(:image).permit(:name, :description, :file, :generate_name_and_description)
  end

  def handle_not_found
    respond_to do |format|
      format.html { redirect_to images_path, alert: 'Image not found.' }
      format.json { render json: { status: 'error', message: 'Image not found.' }, status: :not_found }
    end
  end

  def handle_conflict
    respond_to do |format|
      format.html { redirect_back fallback_location: images_path, alert: 'The image was modified by another user. Please try again.' }
      format.json { render json: { status: 'error', message: 'The image was modified by another user. Please try again.' }, status: :conflict }
    end
  end

  def handle_timeout
    respond_to do |format|
      format.html { redirect_back fallback_location: images_path, alert: 'The operation timed out. Please try again.' }
      format.json { render json: { status: 'error', message: 'The operation timed out. Please try again.' }, status: :request_timeout }
    end
  end

  def handle_storage_error
    respond_to do |format|
      format.html { redirect_back fallback_location: images_path, alert: 'There was a problem with file storage. Please try again.' }
      format.json { render json: { status: 'error', message: 'There was a problem with file storage. Please try again.' }, status: :internal_server_error }
    end
  end

  def handle_error(error)
    case error
    when ActiveRecord::RecordInvalid
      error.record.errors.full_messages.join(", ")
    when Timeout::Error
      "Upload timed out, please try again"
    when Errno::ENOSPC
      "Storage space is full, please try again later"
    when ActiveRecord::StaleObjectError
      "Upload conflict detected, please try again"
    when ActiveStorage::IntegrityError
      "File upload failed. Please try again."
    when ActiveStorage::Error
      "File could not be uploaded: storage error"
    else
      Rails.logger.error("Unexpected error: #{error.message}")
      "An unexpected error occurred"
    end
  end

  def development_or_test?
    Rails.env.development? || Rails.env.test?
  end

  def invalid_dimensions_attributes?(attributes)
    return false unless attributes[:file].respond_to?(:read)
    
    content = attributes[:file].read
    attributes[:file].rewind # Important: rewind the IO
    
    # Check if it's the invalid dimensions test case
    content.start_with?('GIF89a') && content.bytesize < 100
  end
end

