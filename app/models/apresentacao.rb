# Apresentação de um artigo num congresso, num ano.
class Apresentacao < ApplicationRecord
  has_paper_trail

  belongs_to :artigo
  belongs_to :congresso

  validates :congresso_id, uniqueness: { scope: [ :artigo_id, :ano ] }
end
