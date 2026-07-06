class ApplicationJob < ActiveJob::Base
  # Falha na DESSERIALIZAÇÃO (registro apagado antes do job rodar) acontece
  # antes dos callbacks de perform — sem isto, sumiria sem rastro.
  rescue_from ActiveJob::DeserializationError do |excecao|
    ErrorLog.registrar(excecao, componente: self.class.name, acao_tentada: "deserialize")
    raise excecao
  end

  # RNF-14: falha em job também vira error_log, com argumentos mascarados
  # (RN-16). O raise segue para o retry_on/discard_on do job — cada
  # tentativa deixa rastro, e "tentativa" agrupa as linhas do incidente.
  around_perform do |job, block|
    block.call
  rescue StandardError => excecao
    ErrorLog.registrar(
      excecao,
      componente: job.class.name,
      acao_tentada: "perform",
      input_payload: { "arguments" => argumentos_mascarados, "tentativa" => executions }
    )
    raise
  end

  private

  # RN-16 à prova de argumento POSICIONAL: o ParameterFilter só mascara por
  # nome de chave, então string solta (pode ser token/senha) é sempre
  # mascarada; número/bool/nil ficam (ids, flags); hash é filtrado por chave;
  # o resto vira o nome da classe.
  def argumentos_mascarados
    arguments.map { |argumento| mascarar(argumento) }
  end

  def mascarar(valor)
    case valor
    when Numeric, TrueClass, FalseClass, NilClass then valor
    when String then "[FILTERED]"
    when Array then valor.map { |item| mascarar(item) }
    when Hash
      ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters).filter(valor)
    else valor.class.name
    end
  end
end
