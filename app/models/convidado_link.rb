# Rede social do convidado (rede + url) — quantas o convidado tiver.
class ConvidadoLink < ApplicationRecord
  belongs_to :convidado

  validates :rede, presence: true
  validates :url, presence: true
end
