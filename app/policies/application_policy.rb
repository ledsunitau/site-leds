# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  private

  # Papéis com poder de gestão (matriz de permissões, seção 3.1 da spec) —
  # usado pelas policies de escrita de todos os domínios.
  def gestor?
    user.present? && (user.diretoria? || user.presidencia?)
  end

  # Membro da liga ou acima (cria/edita Ações e Produtos — RN-13).
  def membro_liga?
    user.present? && (user.membro? || gestor?)
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
