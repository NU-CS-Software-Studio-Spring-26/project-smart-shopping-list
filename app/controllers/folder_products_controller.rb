class FolderProductsController < ApplicationController
  before_action :set_folder

  def create
    product = Current.user.products.find(params[:product_id])
    @folder.products << product unless @folder.products.include?(product)
    redirect_back fallback_location: @folder, notice: "Added to \"#{@folder.name}\"."
  end

  def destroy
    product = Current.user.products.find(params[:id])
    @folder.products.delete(product)
    redirect_back fallback_location: @folder, notice: "Removed from \"#{@folder.name}\"."
  end

  private

  def set_folder
    @folder = Current.user.folders.find(params[:folder_id])
  end
end
