# Raiz mínima exigida pelos redirects do Devise. Os dados reais da landing
# (métricas, destaques) chegam nas branches feature/acoes-* e feature/admin-base.
class HomeController < ApplicationController
  def index
    head :ok
  end
end
