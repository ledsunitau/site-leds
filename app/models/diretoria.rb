class Diretoria < ApplicationRecord
  has_many :mandatos, dependent: :nullify

  validates :nome, presence: true, uniqueness: true
end
