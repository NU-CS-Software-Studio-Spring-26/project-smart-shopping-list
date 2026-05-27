class Folder < ApplicationRecord
  belongs_to :user
  has_many :folder_products, dependent: :destroy
  has_many :products, through: :folder_products

  validates :name, presence: true, length: { maximum: 80 }
  validates :name, uniqueness: { scope: :user_id, message: "you already have a folder with that name" }
  validates :description, length: { maximum: 300 }, allow_blank: true
end
