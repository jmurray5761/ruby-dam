class ImagesController < ApplicationController
  include Pagy::Backend
  
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::StaleObjectError, with: :handle_concurrent_upload
  rescue_from Timeout::Error, with: :handle_timeout

  def index
    @pagy, @images = pagy(Image.includes(file_attachment: { blob: :variant_records }).order(created_at: :desc), items: 20)
    
    respond_to do |format|
      format.html
      format.json { render json: { images: @images, pagy: @pagy } }
    end
  end

  def show
    @image = Image.find(params[:id])
    
    respond_to do |format|
      format.html
      format.json { render json: @image }
    end
  end

  def new
    @image = Image.new
  end

  def create
    Rails.logger.info("Starting image creation")
    Rails.logger.info("Raw params: #{params.inspect}")
    Rails.logger.info("Image params: #{params[:image].inspect}")
    Rails.logger.info("Generate flag from params: #{params[:image][:generate_name_and_description]}")
    
    @image = Image.new(image_params)
    Rails.logger.info("Image attributes after initialization: #{@image.attributes.inspect}")
    Rails.logger.info("Generate flag after initialization: #{@image.generate_name_and_description}")

    begin
      if @image.save
        Rails.logger.info("Image saved successfully")
        respond_to do |format|
          format.html { redirect_to @image, notice: 'Image was successfully uploaded and processed.' }
          format.json { render json: { status: 'success', message: 'Image was successfully uploaded and processed.', image: @image }, status: :created }
        end
      else
        handle_validation_error
      end
    rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError => e
      Rails.logger.error("File upload error: #{e.message}")
      @image.errors.add(:file, "File upload failed. Please try again.")
      handle_validation_error
    rescue ActiveRecord::StaleObjectError => e
      handle_concurrent_upload(e)
    rescue Timeout::Error => e
      Rails.logger.error("Upload timeout error: #{e.message}")
      @image.errors.add(:base, "Upload timed out, please try again")
      handle_validation_error
    rescue StandardError => e
      Rails.logger.error("Standard error during #{action_name}: #{e.message}")
      @image.errors.add(:base, "File could not be uploaded: storage error")
      handle_validation_error
    end
  end

  def edit
    @image = Image.find(params[:id])
  end

  def update
    @image = Image.find(params[:id])
    
    if @image.update(image_params)
      respond_to do |format|
        format.html { redirect_to @image, notice: 'Image was successfully updated.' }
        format.json { render json: { status: 'success', message: 'Image was successfully updated.', image: @image } }
      end
    else
      handle_validation_error
    end
  end

  def destroy
    @image = Image.find_by(id: params[:id])
    if @image
      @image.destroy
      if @image.destroyed?
        message = "Image and associated files deleted successfully."
        respond_to do |format|
          format.html { redirect_to images_url, notice: message, status: :see_other }
          format.json { render json: { status: 'success', message: message } }
        end
      else
        message = "Failed to delete the image."
        respond_to do |format|
          format.html { redirect_to images_url, alert: message, status: :unprocessable_entity }
          format.json { render json: { status: 'error', message: message }, status: :unprocessable_entity }
        end
      end
    else
      message = "Image not found."
      respond_to do |format|
        format.html { redirect_to images_url, alert: message, status: :not_found }
        format.json { render json: { status: 'error', message: message }, status: :not_found }
      end
    end
  end

  private

  def image_params
    params.require(:image).permit(:name, :description, :file, :generate_name_and_description)
  end

  def handle_validation_error
    respond_to do |format|
      format.html { render action_name == 'update' ? :edit : :new, status: :unprocessable_entity }
      format.json { render json: { status: 'error', errors: @image.errors }, status: :unprocessable_entity }
    end
  end

  def handle_not_found(error)
    respond_to do |format|
      format.html { redirect_to images_url, alert: 'Image not found.' }
      format.json { render json: { status: 'error', message: 'Image not found.' }, status: :not_found }
    end
  end

  def handle_simulated_errors
    if params[:simulate_timeout]
      @image.errors.add(:base, 'Upload timed out, please try again')
      raise Timeout::Error, "Upload timed out"
    elsif params[:simulate_disk_full]
      @image.errors.add(:base, 'File could not be uploaded: storage error')
      raise StandardError, "Disk is full"
    end
  end

  def handle_timeout(error)
    Rails.logger.error("Upload timeout error: #{error.message}")
    handle_validation_error
  end

  def handle_concurrent_upload(error)
    Rails.logger.error("Concurrent upload error: #{error.message}")
    @image.errors.add(:base, 'Upload conflict detected, please try again')
    handle_validation_error
  end

  def development_or_test?
    Rails.env.development? || Rails.env.test?
  end
end
