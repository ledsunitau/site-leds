# Regras de upload de imagem (fotos, thumbnails, ícones, imagem de produto):
# só formatos web, tamanho limitado.
#
# ATENÇÃO ao servir: a URL sai por rails_blob_path (FotoUrl), rota do Active
# Storage que NÃO passa pelo Devise. O signed_id não é adivinhável — quem receber
# o link lê o arquivo sem sessão. Isso é indiferente para o que já é público
# (membro, post, parceiro), mas a loja exige login para LER (RN-17): o JSON está
# protegido, o byte da imagem não.
# DECISÃO (deploy): NÃO gatear o byte. Membro/post/produto passam pelas MESMAS
# rotas do Active Storage; gatear só produto exigiria uma rota autenticada custom
# por anexo. Custo alto para baixa sensibilidade (fotos de produto, catálogo já
# protegido, signed_id não-enumerável). Isso continua valendo tal e qual.
#
# Produção usa PROXY mode (config/environments/production.rb) desde o bug da foto
# que sumia: a rota de proxy é tão pública quanto a de redirect, então nada aqui
# muda — o que mudou foi só a entrega do byte. A alavanca de gatear a loja, se um
# dia importar, continua sendo uma rota autenticada custom, agora sem precisar
# trocar o modo antes.
#
#   include ImagemValidavel
#   valida_imagem :thumbnail
module ImagemValidavel
  extend ActiveSupport::Concern

  TIPOS = %w[image/jpeg image/png image/webp].freeze
  TAMANHO_MAX = 5.megabytes

  # Opções COMUNS a toda variante do site — só as medidas mudam por anexo.
  # Ficam aqui porque divergir é o modo de falha real: uma variante esquecida em
  # JPEG ou sem preprocessed passa despercebida até virar peso em produção.
  #
  #   has_one_attached :foto do |anexo|
  #     anexo.variant :avatar, resize_to_limit: [96, 96], **ImagemValidavel::VARIANTE
  #   end
  #
  # preprocessed: gera no upload (job do Solid Queue) em vez de na primeira
  # visita — quem abre a página não paga o processamento. Registro antigo, que
  # não tem a variante, gera sob demanda no primeiro acesso e cacheia.
  # resize_to_limit: nunca faz upscale e preserva proporção, então uma foto menor
  # que o limite passa intacta em vez de ser esticada.
  # webp é seguro: o allow_browser :modern do ApplicationController já o exige.
  VARIANTE = { format: :webp, saver: { quality: 80 }, preprocessed: true }.freeze

  class_methods do
    # tipos:/formatos: permitem casos como logo de parceiro (aceita SVG) sem
    # afrouxar as demais imagens (foto, thumbnail, ícone) — que seguem raster.
    #
    # minimo: [largura, altura] recusa imagem pequena demais para o lugar onde
    # ela vai aparecer. resize_to_limit NUNCA amplia, então uma imagem menor que
    # a caixa passa intacta pela variante e quem amplia é o background-size:cover
    # do CSS — na tela do leitor, sem nenhum aviso para quem subiu. Só faz
    # sentido onde há um tamanho de exibição conhecido (capa de novidade).
    def valida_imagem(nome, tipos: TIPOS, formatos: "JPEG, PNG ou WebP", minimo: nil)
      validate do
        anexo = public_send(nome)
        next unless anexo.attached?

        # has_one_attached devolve UM anexo; has_many_attached, uma coleção. As
        # duas passam pelas mesmas regras: uma foto de galeria é upload de
        # usuário igual à principal, e ficar de fora do type/size seria um buraco
        # aberto — não uma economia.
        #
        # is_a? e NÃO respond_to?(:attachments): num Attached::One COM arquivo o
        # respond_to? responde true, porque ele delega o que não conhece para o
        # Attachment, que delega para o Blob, que tem has_many :attachments. Vazio
        # dá false, anexado dá true — o discriminador mudava de resposta conforme
        # o estado, e a validação de dimensão mínima da capa parou de rodar.
        colecao = anexo.is_a?(ActiveStorage::Attached::Many)
        anexos = colecao ? anexo.attachments : [ anexo ]

        # any? e não um errors.add por arquivo: com 5 fotos erradas a tela
        # repetiria a mesma frase cinco vezes.
        errors.add(nome, "deve ser #{formatos}") if anexos.any? { |i| !i.content_type.in?(tipos) }
        errors.add(nome, "deve ter no máximo 5 MB") if anexos.any? { |i| i.byte_size > TAMANHO_MAX }

        # minimo: só faz sentido onde há UM anexo com um tamanho de exibição
        # conhecido. Numa coleção não há "o" lugar onde a foto aparece — e
        # dimensoes() abaixo lê anexo.blob, que Attached::Many nem tem.
        next if minimo.nil? || colecao
        # Arquivo já reprovado no tipo ou no tamanho não é medido: a mensagem de
        # dimensão seria ruído sobre um erro que a pessoa já tem para corrigir, e
        # medir exige ler o arquivo inteiro — que é justo o que o limite de 5 MB
        # acabou de dizer que não vale a pena fazer.
        next if errors[nome].any?

        largura, altura = ImagemValidavel.dimensoes(anexo)
        # Dimensão desconhecida = passa. Não é descuido: sem analisador de imagem
        # (o runner do CI não roda no Docker e não tem libvips — a mesma razão do
        # `require: false` no ruby-vips) o metadata vem vazio, e barrar upload por
        # falta de biblioteca no servidor seria pior que aceitar uma capa pequena.
        next if largura.nil? || altura.nil?
        next if largura >= minimo[0] && altura >= minimo[1]

        errors.add(nome, "deve ter no mínimo #{minimo[0]}x#{minimo[1]}px — a sua tem " \
                         "#{largura}x#{altura}px e ficaria pixelada ao ser ampliada na página")
      end
    end
  end

  # Largura e altura da imagem NA HORA da validação. Três caminhos, porque o
  # metadata do blob quase nunca está pronto quando a validação roda:
  #
  #   já analisado    → lê o metadata (edição que não trocou a imagem)
  #   blob gravado    → analisa agora, em vez de esperar o AnalyzeJob
  #   upload pendente → mede o arquivo temporário
  #
  # O terceiro é o que importa e o que quase passou batido: num upload de
  # formulário o blob só é enviado ao service DEPOIS de salvar, e a validação
  # roda antes. `blob.analyze` ali tenta baixar um arquivo que ainda não existe,
  # levanta, e a validação passava — a capa pequena entrava no ar em silêncio,
  # exatamente o que ela existe para impedir. O teste não pegava porque fixava o
  # metadata; só a verificação no app rodando mostrou.
  def self.dimensoes(anexo)
    blob = anexo.blob
    return [ nil, nil ] unless blob&.image?
    return blob.metadata.values_at("width", "height") if blob.analyzed?

    if blob.persisted?
      blob.analyze
      blob.metadata.values_at("width", "height")
    else
      medir_pendente(anexo)
    end
  rescue StandardError
    # Blob corrompido ou analisador ausente: mesma decisão do `next if nil` da
    # validação — sem medida confiável, não bloqueia.
    [ nil, nil ]
  end

  # Mede o arquivo do upload com a MESMA libvips que gera as variantes. O
  # `require` é local e pode falhar: onde não há libvips (o runner do CI) isto
  # cai no rescue de dimensoes e a validação passa, como documentado lá.
  def self.medir_pendente(anexo)
    io = nil
    anexavel = anexo.record.attachment_changes[anexo.name.to_s]&.attachable
    # UploadedFile do formulário → tempfile; attach(io:) → o Hash; File puro → ele mesmo.
    io = anexavel.respond_to?(:tempfile) ? anexavel.tempfile : anexavel
    io = io[:io] if io.is_a?(Hash)
    return [ nil, nil ] unless io.respond_to?(:read)

    require "vips"
    io.rewind
    imagem = Vips::Image.new_from_buffer(io.read, "")
    [ imagem.width, imagem.height ]
  ensure
    # O mesmo io ainda vai ser lido no save para subir o arquivo. Sem rewind, o
    # blob sobe vazio — a validação teria corrompido o upload que aprovou.
    io.rewind if io.respond_to?(:rewind)
  end
end
