# Portão do namespace /admin (RF-ADM-01): só diretoria e presidência.
# O Mission Control (/admin/jobs) herda daqui via base_controller_class.
class Admin::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :exigir_gestao!

  private

  def exigir_gestao!
    head :forbidden unless current_user.gestao?
  end
end
