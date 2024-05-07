class ImagesController < ApplicationController
  include Pagy::Backend

  def index
    @pagy, @images = pagy(Image.all, items: 10)
  end

  def show
    @image = Image.find(params[:id])
  end

  def new
    @image = Image.new
  end

  def create
    @image = Image.new(image_params)
    if @image.save
      redirect_to @image, notice: 'Image was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @image = Image.find(params[:id])
  end

  def update
    @image = Image.find(params[:id])
    if @image.update(image_params)
      redirect_to @image
    else
      render :edit, status: :unprocessable_entity
    end
  end
  def destroy
    @image = Image.find(params[:id])
    @image.destroy
    redirect_to root_path, status: :see_other
  end

  private

  def image_params
    params.require(:image).permit(:name, :description, :file)
  end
end
