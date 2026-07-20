require "digest"

# Cotação de frete cacheada (RF-LOJ-11 + §7.3 anti-cota): a mesma combinação
# CEP+peso+dimensões não re-consulta o Melhor Envio dentro da janela — protege a
# cota da API (RNF-15/01). Chave pelos dados reais (peso/dimensões), então mudar
# a dimensão de uma variante invalida o cache naturalmente.
module Frete
  module_function

  def cotar(cep_destino, itens)
    Rails.cache.fetch(chave_cache(cep_destino, itens), expires_in: 12.hours) do
      MelhorEnvio.cotar(cep_destino, itens)
    end
  end

  def chave_cache(cep_destino, itens)
    dims = itens.map do |i|
      v = i.variante
      [ v&.peso, v&.altura, v&.largura, v&.comprimento, i.quantidade ]
    end.sort_by(&:to_s)
    "frete/#{MelhorEnvio.so_digitos(cep_destino)}/#{Digest::SHA1.hexdigest(dims.to_s)}"
  end
end
