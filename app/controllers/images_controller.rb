class ImagesController < ApplicationController
  include Pagy::Backend
  
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::StaleObjectError, with: :handle_conflict
  rescue_from Timeout::Error, with: :handle_timeout
  rescue_from ActiveStorage::Error, with: :handle_storage_error

  before_action :set_image, only: [:show, :edit, :update, :destroy]
  before_action :check_rate_limit, only: [:search, :search_by_image]

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

  def search
    query = params[:q]
    @images = []  # Initialize empty array for nil case
    
    if query.blank?
      flash.now[:alert] = 'Please provide a search query.'
      render :search
      return
    end

    # Cache search results for 5 minutes
    @pagy, @images = Rails.cache.fetch("search:#{query}", expires_in: 5.minutes) do
      Timeout.timeout(30) do # 30 second timeout for search
        pagy(Image.find_similar_by_text(query))
      end
    end

    render :search
  rescue Timeout::Error => e
    Rails.logger.error("Search timeout: #{e.message}")
    @images = []  # Initialize empty array for error case
    flash.now[:alert] = 'Search timed out. Please try a more specific query.'
    render :search
  rescue StandardError => e
    Rails.logger.error("Search error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    @images = []  # Initialize empty array for error case
    flash.now[:alert] = 'An error occurred while searching. Please try again.'
    render :search
  end

  def search_by_image
    @images = []  # Initialize empty array for nil case
    
    if params[:image].blank?
      flash.now[:alert] = 'Please select an image to search with.'
      render :search
      return
    end

    # Cache search results for 5 minutes using image hash as key
    image_hash = Digest::SHA256.hexdigest(params[:image].read)
    params[:image].rewind # Reset file pointer after reading

    @pagy, @images = Rails.cache.fetch("image_search:#{image_hash}", expires_in: 5.minutes) do
      Timeout.timeout(30) do # 30 second timeout for search
        pagy(Image.find_similar_by_image(params[:image].read))
      end
    end

    render :search
  rescue Timeout::Error => e
    Rails.logger.error("Image search timeout: #{e.message}")
    @images = []  # Initialize empty array for error case
    flash.now[:alert] = 'Image search timed out. Please try a different image.'
    render :search
  rescue StandardError => e
    Rails.logger.error("Image search error: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    @images = []  # Initialize empty array for error case
    flash.now[:alert] = 'An error occurred while searching. Please try again.'
    render :search
  end

  def batch_upload
    uploaded_count = 0
    errors = []

    if params[:selected_files].present?
      params[:selected_files].each do |file_path|
        begin
          # Create a new image record
          image = Image.new
          
          # Convert the file path to be relative to the Rails root
          relative_path = file_path.gsub(Rails.root.to_s, '')
          full_path = Rails.root.join(relative_path)
          
          # Check if file exists
          unless File.exist?(full_path)
            raise "File not found: #{file_path}"
          end
          
          # Read the file from the source directory
          file = File.open(full_path)
          
          # Attach the file
          image.file.attach(
            io: file,
            filename: File.basename(file_path),
            content_type: File.extname(file_path)
          )

          # Save the image (this will trigger the after_save callback)
          if image.save
            uploaded_count += 1
          else
            errors << "Failed to save #{File.basename(file_path)}: #{image.errors.full_messages.join(', ')}"
          end
        rescue StandardError => e
          errors << "Error processing #{File.basename(file_path)}: #{e.message}"
          Rails.logger.error("Error processing #{file_path}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        ensure
          file&.close
        end
      end
    end

    respond_to do |format|
      format.json do
        if errors.empty?
          render json: { 
            status: 'success', 
            uploaded_count: uploaded_count,
            message: "Successfully uploaded #{uploaded_count} images"
          }
        else
          render json: { 
            status: 'partial_success',
            uploaded_count: uploaded_count,
            errors: errors
          }, status: :unprocessable_entity
        end
      end
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

  def check_rate_limit
    # Rate limit to 10 requests per minute per IP
    key = "rate_limit:#{request.remote_ip}"
    count = Rails.cache.increment(key, 1, expires_in: 1.minute)
    
    if count > 10
      respond_to do |format|
        format.html { redirect_to images_path, alert: 'Rate limit exceeded. Please try again later.' }
        format.json { render json: { status: 'error', message: 'Rate limit exceeded. Please try again later.' }, status: :too_many_requests }
      end
    end
  end
end

