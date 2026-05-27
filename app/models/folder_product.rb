class FolderProduct < ApplicationRecord
  belongs_to :folder
  belongs_to :product
end
