class ArtigoTema < ApplicationRecord
  has_paper_trail

  belongs_to :artigo
  belongs_to :tema

  validates :tema_id, uniqueness: { scope: :artigo_id }
end
