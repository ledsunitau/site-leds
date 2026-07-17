SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: trg_artigo_temas_max(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_artigo_temas_max() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- endurecimento documentado sobre o DDL: trava a linha do artigo para
  -- serializar inserts concorrentes; sem isto duas transações passam
  -- do máximo (cada uma vê count=2 e ambas commitam)
  PERFORM 1 FROM artigos WHERE id = NEW.artigo_id FOR UPDATE;
  IF (SELECT count(*) FROM artigo_temas WHERE artigo_id = NEW.artigo_id) >= 3 THEN
    RAISE EXCEPTION 'Um artigo pode ter no máximo 3 temas (artigo_id=%)', NEW.artigo_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: trg_produto_indisponivel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_produto_indisponivel() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.status = 'indisponivel' AND OLD.status IS DISTINCT FROM 'indisponivel' THEN
    DELETE FROM itens_carrinho WHERE produto_id = NEW.id;
    UPDATE reservas SET status = 'cancelada', updated_at = now()
     WHERE produto_id = NEW.id AND status = 'ativa';
  END IF;
  RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: acao_parceiros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.acao_parceiros (
    id bigint NOT NULL,
    acao_id bigint NOT NULL,
    parceiro_id bigint NOT NULL
);


--
-- Name: acao_parceiros_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.acao_parceiros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: acao_parceiros_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.acao_parceiros_id_seq OWNED BY public.acao_parceiros.id;


--
-- Name: acoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.acoes (
    id bigint NOT NULL,
    detalhe_type character varying NOT NULL,
    detalhe_id bigint NOT NULL,
    titulo character varying NOT NULL,
    descricao text,
    status character varying DEFAULT 'rascunho'::character varying NOT NULL,
    created_by bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    ideia_id bigint,
    CONSTRAINT acoes_detalhe_type_check CHECK (((detalhe_type)::text = ANY ((ARRAY['Projeto'::character varying, 'Evento'::character varying, 'Artigo'::character varying])::text[]))),
    CONSTRAINT acoes_status_check CHECK (((status)::text = ANY ((ARRAY['rascunho'::character varying, 'publicada'::character varying, 'arquivada'::character varying])::text[])))
);


--
-- Name: acoes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.acoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: acoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.acoes_id_seq OWNED BY public.acoes.id;


--
-- Name: action_text_rich_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_text_rich_texts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    body text,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_text_rich_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_text_rich_texts_id_seq OWNED BY public.action_text_rich_texts.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: analytics_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.analytics_events (
    id bigint NOT NULL,
    user_id bigint,
    anonymous_id character varying,
    nome character varying NOT NULL,
    rota character varying,
    referrer character varying,
    ocorrido_em timestamp(6) without time zone NOT NULL,
    metadata jsonb,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: analytics_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.analytics_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: analytics_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.analytics_events_id_seq OWNED BY public.analytics_events.id;


--
-- Name: apresentacoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.apresentacoes (
    id bigint NOT NULL,
    artigo_id bigint NOT NULL,
    congresso_id bigint NOT NULL,
    ano integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: apresentacoes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.apresentacoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: apresentacoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.apresentacoes_id_seq OWNED BY public.apresentacoes.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: artigo_temas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artigo_temas (
    id bigint NOT NULL,
    artigo_id bigint NOT NULL,
    tema_id bigint NOT NULL
);


--
-- Name: artigo_temas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.artigo_temas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artigo_temas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.artigo_temas_id_seq OWNED BY public.artigo_temas.id;


--
-- Name: artigos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artigos (
    id bigint NOT NULL,
    abstract text,
    revista character varying,
    publicacao_url character varying,
    situacao character varying DEFAULT 'em_desenvolvimento'::character varying NOT NULL,
    data_finalizacao date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT artigos_situacao_check CHECK (((situacao)::text = ANY ((ARRAY['em_desenvolvimento'::character varying, 'finalizado'::character varying])::text[]))),
    CONSTRAINT artigos_situacao_data_check CHECK (((((situacao)::text = 'finalizado'::text) AND (data_finalizacao IS NOT NULL)) OR (((situacao)::text = 'em_desenvolvimento'::text) AND (data_finalizacao IS NULL))))
);


--
-- Name: artigos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.artigos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: artigos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.artigos_id_seq OWNED BY public.artigos.id;


--
-- Name: autores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.autores (
    id bigint NOT NULL,
    artigo_id bigint NOT NULL,
    member_id bigint,
    nome character varying NOT NULL,
    lattes_url character varying,
    ordem integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: autores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.autores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: autores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.autores_id_seq OWNED BY public.autores.id;


--
-- Name: carrinhos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.carrinhos (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: carrinhos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.carrinhos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: carrinhos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.carrinhos_id_seq OWNED BY public.carrinhos.id;


--
-- Name: comentarios; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comentarios (
    id bigint NOT NULL,
    post_id bigint NOT NULL,
    user_id bigint,
    corpo text NOT NULL,
    status character varying DEFAULT 'visivel'::character varying NOT NULL,
    moderated_by bigint,
    moderated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT comentarios_status_check CHECK (((status)::text = ANY ((ARRAY['visivel'::character varying, 'oculto'::character varying, 'removido'::character varying])::text[])))
);


--
-- Name: comentarios_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.comentarios_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: comentarios_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.comentarios_id_seq OWNED BY public.comentarios.id;


--
-- Name: congressos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.congressos (
    id bigint NOT NULL,
    nome character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: congressos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.congressos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: congressos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.congressos_id_seq OWNED BY public.congressos.id;


--
-- Name: contribuicoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contribuicoes (
    id bigint NOT NULL,
    projeto_id bigint NOT NULL,
    member_id bigint NOT NULL,
    papel character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT contribuicoes_papel_check CHECK (((papel)::text = ANY ((ARRAY['backend'::character varying, 'frontend'::character varying, 'ui_ux'::character varying, 'design'::character varying, 'infra'::character varying, 'outro'::character varying])::text[])))
);


--
-- Name: contribuicoes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.contribuicoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contribuicoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.contribuicoes_id_seq OWNED BY public.contribuicoes.id;


--
-- Name: convidado_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.convidado_links (
    id bigint NOT NULL,
    convidado_id bigint NOT NULL,
    rede character varying NOT NULL,
    url character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: convidado_links_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.convidado_links_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: convidado_links_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.convidado_links_id_seq OWNED BY public.convidado_links.id;


--
-- Name: convidados; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.convidados (
    id bigint NOT NULL,
    evento_id bigint NOT NULL,
    nome character varying NOT NULL,
    bio text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: convidados_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.convidados_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: convidados_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.convidados_id_seq OWNED BY public.convidados.id;


--
-- Name: cookie_consents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cookie_consents (
    id bigint NOT NULL,
    user_id bigint,
    anonymous_id character varying,
    analytics boolean DEFAULT false NOT NULL,
    marketing boolean DEFAULT false NOT NULL,
    consented_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: cookie_consents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cookie_consents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cookie_consents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cookie_consents_id_seq OWNED BY public.cookie_consents.id;


--
-- Name: denuncias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.denuncias (
    id bigint NOT NULL,
    comentario_id bigint NOT NULL,
    user_id bigint,
    motivo character varying,
    status character varying DEFAULT 'pendente'::character varying NOT NULL,
    resolved_by bigint,
    resolved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT denuncias_status_check CHECK (((status)::text = ANY ((ARRAY['pendente'::character varying, 'resolvida'::character varying])::text[])))
);


--
-- Name: denuncias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.denuncias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: denuncias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.denuncias_id_seq OWNED BY public.denuncias.id;


--
-- Name: diretorias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diretorias (
    id bigint NOT NULL,
    nome character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: diretorias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.diretorias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: diretorias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.diretorias_id_seq OWNED BY public.diretorias.id;


--
-- Name: error_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.error_logs (
    id bigint NOT NULL,
    user_id bigint,
    occurred_at timestamp(6) without time zone NOT NULL,
    rota character varying,
    componente character varying,
    acao_tentada character varying,
    input_payload jsonb,
    error_class character varying,
    error_message text,
    backtrace text,
    severidade character varying DEFAULT 'error'::character varying NOT NULL,
    ambiente character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT error_logs_severidade_check CHECK (((severidade)::text = ANY ((ARRAY['info'::character varying, 'warning'::character varying, 'error'::character varying, 'fatal'::character varying])::text[])))
);


--
-- Name: error_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.error_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: error_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.error_logs_id_seq OWNED BY public.error_logs.id;


--
-- Name: evento_membros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evento_membros (
    id bigint NOT NULL,
    evento_id bigint NOT NULL,
    member_id bigint NOT NULL,
    papel character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT evento_membros_papel_check CHECK (((papel)::text = ANY ((ARRAY['organizador'::character varying, 'participante'::character varying])::text[])))
);


--
-- Name: evento_membros_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.evento_membros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: evento_membros_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.evento_membros_id_seq OWNED BY public.evento_membros.id;


--
-- Name: eventos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.eventos (
    id bigint NOT NULL,
    local character varying,
    data_inicio timestamp(6) without time zone NOT NULL,
    data_fim timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT eventos_datas_check CHECK (((data_fim IS NULL) OR (data_fim >= data_inicio)))
);


--
-- Name: eventos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.eventos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: eventos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.eventos_id_seq OWNED BY public.eventos.id;


--
-- Name: gestoes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gestoes (
    id bigint NOT NULL,
    ano_inicio integer NOT NULL,
    ano_fim integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT gestoes_anos_check CHECK ((ano_fim > ano_inicio))
);


--
-- Name: gestoes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gestoes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gestoes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gestoes_id_seq OWNED BY public.gestoes.id;


--
-- Name: ideias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ideias (
    id bigint NOT NULL,
    user_id bigint,
    tipo character varying NOT NULL,
    titulo character varying NOT NULL,
    descricao text,
    status character varying DEFAULT 'pendente'::character varying NOT NULL,
    reviewed_by bigint,
    reviewed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT ideias_status_check CHECK (((status)::text = ANY ((ARRAY['pendente'::character varying, 'aprovada'::character varying, 'rejeitada'::character varying])::text[]))),
    CONSTRAINT ideias_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['projeto'::character varying, 'pesquisa'::character varying])::text[])))
);


--
-- Name: ideias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ideias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ideias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ideias_id_seq OWNED BY public.ideias.id;


--
-- Name: itens_carrinho; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.itens_carrinho (
    id bigint NOT NULL,
    carrinho_id bigint NOT NULL,
    produto_id bigint NOT NULL,
    variante_id bigint,
    quantidade integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT itens_carrinho_quantidade_check CHECK ((quantidade > 0))
);


--
-- Name: itens_carrinho_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.itens_carrinho_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: itens_carrinho_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.itens_carrinho_id_seq OWNED BY public.itens_carrinho.id;


--
-- Name: mandatos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mandatos (
    id bigint NOT NULL,
    member_id bigint NOT NULL,
    gestao_id bigint NOT NULL,
    diretoria_id bigint,
    cargo character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT mandatos_cargo_check CHECK (((cargo)::text = ANY ((ARRAY['presidente'::character varying, 'vice'::character varying, 'diretor'::character varying, 'orientador'::character varying, 'membro'::character varying])::text[])))
);


--
-- Name: mandatos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mandatos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mandatos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mandatos_id_seq OWNED BY public.mandatos.id;


--
-- Name: members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.members (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    padrinho_id bigint,
    founder boolean DEFAULT false NOT NULL,
    bio text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT members_padrinho_check CHECK (((padrinho_id IS NULL) OR (padrinho_id <> id)))
);


--
-- Name: members_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.members_id_seq OWNED BY public.members.id;


--
-- Name: noticed_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.noticed_events (
    id bigint NOT NULL,
    type character varying,
    record_type character varying,
    record_id bigint,
    params jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    notifications_count integer
);


--
-- Name: noticed_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.noticed_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: noticed_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.noticed_events_id_seq OWNED BY public.noticed_events.id;


--
-- Name: noticed_notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.noticed_notifications (
    id bigint NOT NULL,
    type character varying,
    event_id bigint NOT NULL,
    recipient_type character varying NOT NULL,
    recipient_id bigint NOT NULL,
    read_at timestamp without time zone,
    seen_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: noticed_notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.noticed_notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: noticed_notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.noticed_notifications_id_seq OWNED BY public.noticed_notifications.id;


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    canal character varying NOT NULL,
    categoria character varying NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT notification_preferences_canal_check CHECK (((canal)::text = ANY ((ARRAY['in_app'::character varying, 'email'::character varying, 'push'::character varying, 'discord'::character varying, 'whatsapp'::character varying])::text[])))
);


--
-- Name: notification_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_preferences_id_seq OWNED BY public.notification_preferences.id;


--
-- Name: oauth_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_identities (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    provider character varying NOT NULL,
    uid character varying NOT NULL,
    username character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT oauth_identities_provider_check CHECK (((provider)::text = ANY ((ARRAY['google'::character varying, 'discord'::character varying])::text[])))
);


--
-- Name: oauth_identities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_identities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_identities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_identities_id_seq OWNED BY public.oauth_identities.id;


--
-- Name: parceiros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parceiros (
    id bigint NOT NULL,
    user_id bigint,
    nome character varying NOT NULL,
    descricao text,
    site_url character varying,
    status character varying DEFAULT 'ativo'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT parceiros_status_check CHECK (((status)::text = ANY ((ARRAY['ativo'::character varying, 'inativo'::character varying])::text[])))
);


--
-- Name: parceiros_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parceiros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parceiros_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parceiros_id_seq OWNED BY public.parceiros.id;


--
-- Name: parceria_leads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parceria_leads (
    id bigint NOT NULL,
    empresa character varying NOT NULL,
    contato_nome character varying,
    contato_email character varying NOT NULL,
    tipo character varying NOT NULL,
    descricao text,
    status character varying DEFAULT 'novo'::character varying NOT NULL,
    parceiro_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT parceria_leads_status_check CHECK (((status)::text = ANY ((ARRAY['novo'::character varying, 'em_analise'::character varying, 'convertido'::character varying, 'recusado'::character varying])::text[]))),
    CONSTRAINT parceria_leads_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['software'::character varying, 'pesquisa'::character varying, 'evento'::character varying, 'patrocinio_geral'::character varying])::text[])))
);


--
-- Name: parceria_leads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parceria_leads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parceria_leads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parceria_leads_id_seq OWNED BY public.parceria_leads.id;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id bigint NOT NULL,
    user_id bigint,
    tipo character varying NOT NULL,
    titulo character varying NOT NULL,
    subtitulo character varying,
    caller character varying,
    status character varying DEFAULT 'rascunho'::character varying NOT NULL,
    approved_by bigint,
    approved_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT posts_status_check CHECK (((status)::text = ANY ((ARRAY['rascunho'::character varying, 'em_aprovacao'::character varying, 'publicado'::character varying, 'rejeitado'::character varying])::text[]))),
    CONSTRAINT posts_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['noticia'::character varying, 'blog'::character varying])::text[])))
);


--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.posts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: produtos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.produtos (
    id bigint NOT NULL,
    nome character varying NOT NULL,
    descricao text,
    modo_venda character varying DEFAULT 'estoque'::character varying NOT NULL,
    preco numeric(10,2) NOT NULL,
    preco_promocional numeric(10,2),
    status character varying DEFAULT 'ativo'::character varying NOT NULL,
    quantidade_alvo integer,
    created_by bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT produtos_modo_venda_check CHECK (((modo_venda)::text = ANY ((ARRAY['estoque'::character varying, 'sob_demanda'::character varying])::text[]))),
    CONSTRAINT produtos_preco_check CHECK ((preco >= (0)::numeric)),
    CONSTRAINT produtos_preco_promocional_check CHECK (((preco_promocional IS NULL) OR (preco_promocional >= (0)::numeric))),
    CONSTRAINT produtos_quantidade_alvo_check CHECK (((quantidade_alvo IS NULL) OR (quantidade_alvo > 0))),
    CONSTRAINT produtos_status_check CHECK (((status)::text = ANY ((ARRAY['ativo'::character varying, 'indisponivel'::character varying])::text[])))
);


--
-- Name: produtos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.produtos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: produtos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.produtos_id_seq OWNED BY public.produtos.id;


--
-- Name: projeto_tecnologias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projeto_tecnologias (
    id bigint NOT NULL,
    projeto_id bigint NOT NULL,
    tecnologia_id bigint NOT NULL
);


--
-- Name: projeto_tecnologias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projeto_tecnologias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projeto_tecnologias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projeto_tecnologias_id_seq OWNED BY public.projeto_tecnologias.id;


--
-- Name: projetos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projetos (
    id bigint NOT NULL,
    link character varying,
    repo_url character varying,
    hospedagem character varying,
    situacao character varying DEFAULT 'em_desenvolvimento'::character varying NOT NULL,
    data_finalizacao date,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT projetos_situacao_check CHECK (((situacao)::text = ANY ((ARRAY['em_desenvolvimento'::character varying, 'finalizado'::character varying])::text[]))),
    CONSTRAINT projetos_situacao_data_check CHECK (((((situacao)::text = 'finalizado'::text) AND (data_finalizacao IS NOT NULL)) OR (((situacao)::text = 'em_desenvolvimento'::text) AND (data_finalizacao IS NULL))))
);


--
-- Name: projetos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projetos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projetos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projetos_id_seq OWNED BY public.projetos.id;


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_subscriptions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    endpoint character varying NOT NULL,
    p256dh character varying NOT NULL,
    auth character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.push_subscriptions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.push_subscriptions_id_seq OWNED BY public.push_subscriptions.id;


--
-- Name: reservas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservas (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    produto_id bigint NOT NULL,
    variante_id bigint,
    quantidade integer DEFAULT 1 NOT NULL,
    status character varying DEFAULT 'ativa'::character varying NOT NULL,
    pedido_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT reservas_quantidade_check CHECK ((quantidade > 0)),
    CONSTRAINT reservas_status_check CHECK (((status)::text = ANY ((ARRAY['ativa'::character varying, 'cancelada'::character varying, 'convertida'::character varying])::text[])))
);


--
-- Name: reservas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservas_id_seq OWNED BY public.reservas.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: tecnologias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tecnologias (
    id bigint NOT NULL,
    nome character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: tecnologias_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tecnologias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tecnologias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tecnologias_id_seq OWNED BY public.tecnologias.id;


--
-- Name: temas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.temas (
    id bigint NOT NULL,
    nome character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: temas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.temas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: temas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.temas_id_seq OWNED BY public.temas.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email public.citext NOT NULL,
    encrypted_password character varying DEFAULT ''::character varying NOT NULL,
    name character varying NOT NULL,
    role character varying DEFAULT 'comunidade'::character varying NOT NULL,
    reset_password_token character varying,
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['comunidade'::character varying, 'escritor'::character varying, 'parceiro'::character varying, 'membro'::character varying, 'diretoria'::character varying, 'presidencia'::character varying])::text[])))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: variantes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.variantes (
    id bigint NOT NULL,
    produto_id bigint NOT NULL,
    nome character varying NOT NULL,
    sku character varying,
    estoque integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT variantes_estoque_check CHECK ((estoque >= 0))
);


--
-- Name: variantes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.variantes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: variantes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.variantes_id_seq OWNED BY public.variantes.id;


--
-- Name: versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.versions (
    id bigint NOT NULL,
    item_type character varying NOT NULL,
    item_id bigint NOT NULL,
    event character varying NOT NULL,
    whodunnit character varying,
    object jsonb,
    object_changes jsonb,
    created_at timestamp(6) without time zone
);


--
-- Name: versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.versions_id_seq OWNED BY public.versions.id;


--
-- Name: acao_parceiros id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acao_parceiros ALTER COLUMN id SET DEFAULT nextval('public.acao_parceiros_id_seq'::regclass);


--
-- Name: acoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acoes ALTER COLUMN id SET DEFAULT nextval('public.acoes_id_seq'::regclass);


--
-- Name: action_text_rich_texts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts ALTER COLUMN id SET DEFAULT nextval('public.action_text_rich_texts_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: analytics_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events ALTER COLUMN id SET DEFAULT nextval('public.analytics_events_id_seq'::regclass);


--
-- Name: apresentacoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apresentacoes ALTER COLUMN id SET DEFAULT nextval('public.apresentacoes_id_seq'::regclass);


--
-- Name: artigo_temas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artigo_temas ALTER COLUMN id SET DEFAULT nextval('public.artigo_temas_id_seq'::regclass);


--
-- Name: artigos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artigos ALTER COLUMN id SET DEFAULT nextval('public.artigos_id_seq'::regclass);


--
-- Name: autores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.autores ALTER COLUMN id SET DEFAULT nextval('public.autores_id_seq'::regclass);


--
-- Name: carrinhos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrinhos ALTER COLUMN id SET DEFAULT nextval('public.carrinhos_id_seq'::regclass);


--
-- Name: comentarios id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios ALTER COLUMN id SET DEFAULT nextval('public.comentarios_id_seq'::regclass);


--
-- Name: congressos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.congressos ALTER COLUMN id SET DEFAULT nextval('public.congressos_id_seq'::regclass);


--
-- Name: contribuicoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes ALTER COLUMN id SET DEFAULT nextval('public.contribuicoes_id_seq'::regclass);


--
-- Name: convidado_links id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.convidado_links ALTER COLUMN id SET DEFAULT nextval('public.convidado_links_id_seq'::regclass);


--
-- Name: convidados id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.convidados ALTER COLUMN id SET DEFAULT nextval('public.convidados_id_seq'::regclass);


--
-- Name: cookie_consents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cookie_consents ALTER COLUMN id SET DEFAULT nextval('public.cookie_consents_id_seq'::regclass);


--
-- Name: denuncias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denuncias ALTER COLUMN id SET DEFAULT nextval('public.denuncias_id_seq'::regclass);


--
-- Name: diretorias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diretorias ALTER COLUMN id SET DEFAULT nextval('public.diretorias_id_seq'::regclass);


--
-- Name: error_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_logs ALTER COLUMN id SET DEFAULT nextval('public.error_logs_id_seq'::regclass);


--
-- Name: evento_membros id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_membros ALTER COLUMN id SET DEFAULT nextval('public.evento_membros_id_seq'::regclass);


--
-- Name: eventos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.eventos ALTER COLUMN id SET DEFAULT nextval('public.eventos_id_seq'::regclass);


--
-- Name: gestoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gestoes ALTER COLUMN id SET DEFAULT nextval('public.gestoes_id_seq'::regclass);


--
-- Name: ideias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideias ALTER COLUMN id SET DEFAULT nextval('public.ideias_id_seq'::regclass);


--
-- Name: itens_carrinho id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_carrinho ALTER COLUMN id SET DEFAULT nextval('public.itens_carrinho_id_seq'::regclass);


--
-- Name: mandatos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos ALTER COLUMN id SET DEFAULT nextval('public.mandatos_id_seq'::regclass);


--
-- Name: members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members ALTER COLUMN id SET DEFAULT nextval('public.members_id_seq'::regclass);


--
-- Name: noticed_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.noticed_events ALTER COLUMN id SET DEFAULT nextval('public.noticed_events_id_seq'::regclass);


--
-- Name: noticed_notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.noticed_notifications ALTER COLUMN id SET DEFAULT nextval('public.noticed_notifications_id_seq'::regclass);


--
-- Name: notification_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences ALTER COLUMN id SET DEFAULT nextval('public.notification_preferences_id_seq'::regclass);


--
-- Name: oauth_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities ALTER COLUMN id SET DEFAULT nextval('public.oauth_identities_id_seq'::regclass);


--
-- Name: parceiros id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parceiros ALTER COLUMN id SET DEFAULT nextval('public.parceiros_id_seq'::regclass);


--
-- Name: parceria_leads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parceria_leads ALTER COLUMN id SET DEFAULT nextval('public.parceria_leads_id_seq'::regclass);


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Name: produtos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos ALTER COLUMN id SET DEFAULT nextval('public.produtos_id_seq'::regclass);


--
-- Name: projeto_tecnologias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_tecnologias ALTER COLUMN id SET DEFAULT nextval('public.projeto_tecnologias_id_seq'::regclass);


--
-- Name: projetos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos ALTER COLUMN id SET DEFAULT nextval('public.projetos_id_seq'::regclass);


--
-- Name: push_subscriptions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.push_subscriptions_id_seq'::regclass);


--
-- Name: reservas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas ALTER COLUMN id SET DEFAULT nextval('public.reservas_id_seq'::regclass);


--
-- Name: tecnologias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tecnologias ALTER COLUMN id SET DEFAULT nextval('public.tecnologias_id_seq'::regclass);


--
-- Name: temas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temas ALTER COLUMN id SET DEFAULT nextval('public.temas_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: variantes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variantes ALTER COLUMN id SET DEFAULT nextval('public.variantes_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: acao_parceiros acao_parceiros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acao_parceiros
    ADD CONSTRAINT acao_parceiros_pkey PRIMARY KEY (id);


--
-- Name: acoes acoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acoes
    ADD CONSTRAINT acoes_pkey PRIMARY KEY (id);


--
-- Name: action_text_rich_texts action_text_rich_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts
    ADD CONSTRAINT action_text_rich_texts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: analytics_events analytics_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT analytics_events_pkey PRIMARY KEY (id);


--
-- Name: apresentacoes apresentacoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apresentacoes
    ADD CONSTRAINT apresentacoes_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: artigo_temas artigo_temas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artigo_temas
    ADD CONSTRAINT artigo_temas_pkey PRIMARY KEY (id);


--
-- Name: artigos artigos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artigos
    ADD CONSTRAINT artigos_pkey PRIMARY KEY (id);


--
-- Name: autores autores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.autores
    ADD CONSTRAINT autores_pkey PRIMARY KEY (id);


--
-- Name: carrinhos carrinhos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrinhos
    ADD CONSTRAINT carrinhos_pkey PRIMARY KEY (id);


--
-- Name: comentarios comentarios_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios
    ADD CONSTRAINT comentarios_pkey PRIMARY KEY (id);


--
-- Name: congressos congressos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.congressos
    ADD CONSTRAINT congressos_pkey PRIMARY KEY (id);


--
-- Name: contribuicoes contribuicoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes
    ADD CONSTRAINT contribuicoes_pkey PRIMARY KEY (id);


--
-- Name: convidado_links convidado_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.convidado_links
    ADD CONSTRAINT convidado_links_pkey PRIMARY KEY (id);


--
-- Name: convidados convidados_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.convidados
    ADD CONSTRAINT convidados_pkey PRIMARY KEY (id);


--
-- Name: cookie_consents cookie_consents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cookie_consents
    ADD CONSTRAINT cookie_consents_pkey PRIMARY KEY (id);


--
-- Name: denuncias denuncias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denuncias
    ADD CONSTRAINT denuncias_pkey PRIMARY KEY (id);


--
-- Name: diretorias diretorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diretorias
    ADD CONSTRAINT diretorias_pkey PRIMARY KEY (id);


--
-- Name: error_logs error_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_logs
    ADD CONSTRAINT error_logs_pkey PRIMARY KEY (id);


--
-- Name: evento_membros evento_membros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_membros
    ADD CONSTRAINT evento_membros_pkey PRIMARY KEY (id);


--
-- Name: eventos eventos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.eventos
    ADD CONSTRAINT eventos_pkey PRIMARY KEY (id);


--
-- Name: gestoes gestoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gestoes
    ADD CONSTRAINT gestoes_pkey PRIMARY KEY (id);


--
-- Name: ideias ideias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideias
    ADD CONSTRAINT ideias_pkey PRIMARY KEY (id);


--
-- Name: itens_carrinho itens_carrinho_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_carrinho
    ADD CONSTRAINT itens_carrinho_pkey PRIMARY KEY (id);


--
-- Name: mandatos mandatos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos
    ADD CONSTRAINT mandatos_pkey PRIMARY KEY (id);


--
-- Name: members members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT members_pkey PRIMARY KEY (id);


--
-- Name: noticed_events noticed_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.noticed_events
    ADD CONSTRAINT noticed_events_pkey PRIMARY KEY (id);


--
-- Name: noticed_notifications noticed_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.noticed_notifications
    ADD CONSTRAINT noticed_notifications_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (id);


--
-- Name: oauth_identities oauth_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities
    ADD CONSTRAINT oauth_identities_pkey PRIMARY KEY (id);


--
-- Name: parceiros parceiros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parceiros
    ADD CONSTRAINT parceiros_pkey PRIMARY KEY (id);


--
-- Name: parceria_leads parceria_leads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parceria_leads
    ADD CONSTRAINT parceria_leads_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: produtos produtos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT produtos_pkey PRIMARY KEY (id);


--
-- Name: projeto_tecnologias projeto_tecnologias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_tecnologias
    ADD CONSTRAINT projeto_tecnologias_pkey PRIMARY KEY (id);


--
-- Name: projetos projetos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos
    ADD CONSTRAINT projetos_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: reservas reservas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT reservas_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: tecnologias tecnologias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tecnologias
    ADD CONSTRAINT tecnologias_pkey PRIMARY KEY (id);


--
-- Name: temas temas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.temas
    ADD CONSTRAINT temas_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: variantes variantes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variantes
    ADD CONSTRAINT variantes_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: index_acao_parceiros_on_acao_id_and_parceiro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_acao_parceiros_on_acao_id_and_parceiro_id ON public.acao_parceiros USING btree (acao_id, parceiro_id);


--
-- Name: index_acao_parceiros_on_parceiro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acao_parceiros_on_parceiro_id ON public.acao_parceiros USING btree (parceiro_id);


--
-- Name: index_acoes_on_detalhe_type_and_detalhe_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_acoes_on_detalhe_type_and_detalhe_id ON public.acoes USING btree (detalhe_type, detalhe_id);


--
-- Name: index_acoes_on_ideia_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acoes_on_ideia_id ON public.acoes USING btree (ideia_id);


--
-- Name: index_acoes_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acoes_on_status ON public.acoes USING btree (status);


--
-- Name: index_action_text_rich_texts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_text_rich_texts_uniqueness ON public.action_text_rich_texts USING btree (record_type, record_id, name);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_analytics_events_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_events_on_nome ON public.analytics_events USING btree (nome);


--
-- Name: index_analytics_events_on_ocorrido_em; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_events_on_ocorrido_em ON public.analytics_events USING btree (ocorrido_em);


--
-- Name: index_analytics_events_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_analytics_events_on_user_id ON public.analytics_events USING btree (user_id);


--
-- Name: index_apresentacoes_on_artigo_id_and_congresso_id_and_ano; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_apresentacoes_on_artigo_id_and_congresso_id_and_ano ON public.apresentacoes USING btree (artigo_id, congresso_id, ano);


--
-- Name: index_apresentacoes_on_congresso_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_apresentacoes_on_congresso_id ON public.apresentacoes USING btree (congresso_id);


--
-- Name: index_artigo_temas_on_artigo_id_and_tema_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_artigo_temas_on_artigo_id_and_tema_id ON public.artigo_temas USING btree (artigo_id, tema_id);


--
-- Name: index_artigo_temas_on_tema_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_artigo_temas_on_tema_id ON public.artigo_temas USING btree (tema_id);


--
-- Name: index_autores_on_artigo_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_autores_on_artigo_id ON public.autores USING btree (artigo_id);


--
-- Name: index_autores_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_autores_on_member_id ON public.autores USING btree (member_id);


--
-- Name: index_carrinhos_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_carrinhos_on_user_id ON public.carrinhos USING btree (user_id);


--
-- Name: index_comentarios_on_post_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comentarios_on_post_id ON public.comentarios USING btree (post_id);


--
-- Name: index_comentarios_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comentarios_on_status ON public.comentarios USING btree (status);


--
-- Name: index_comentarios_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_comentarios_on_user_id ON public.comentarios USING btree (user_id);


--
-- Name: index_congressos_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_congressos_on_nome ON public.congressos USING btree (nome);


--
-- Name: index_contribuicoes_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contribuicoes_on_member_id ON public.contribuicoes USING btree (member_id);


--
-- Name: index_contribuicoes_on_projeto_id_and_member_id_and_papel; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_contribuicoes_on_projeto_id_and_member_id_and_papel ON public.contribuicoes USING btree (projeto_id, member_id, papel);


--
-- Name: index_convidado_links_on_convidado_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_convidado_links_on_convidado_id ON public.convidado_links USING btree (convidado_id);


--
-- Name: index_convidados_on_evento_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_convidados_on_evento_id ON public.convidados USING btree (evento_id);


--
-- Name: index_cookie_consents_on_anonymous_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cookie_consents_on_anonymous_id ON public.cookie_consents USING btree (anonymous_id);


--
-- Name: index_cookie_consents_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_cookie_consents_on_user_id ON public.cookie_consents USING btree (user_id);


--
-- Name: index_denuncias_on_comentario_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_denuncias_on_comentario_id ON public.denuncias USING btree (comentario_id);


--
-- Name: index_denuncias_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_denuncias_on_status ON public.denuncias USING btree (status);


--
-- Name: index_diretorias_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_diretorias_on_nome ON public.diretorias USING btree (nome);


--
-- Name: index_error_logs_on_occurred_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_logs_on_occurred_at ON public.error_logs USING btree (occurred_at);


--
-- Name: index_error_logs_on_rota; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_logs_on_rota ON public.error_logs USING btree (rota);


--
-- Name: index_error_logs_on_severidade; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_logs_on_severidade ON public.error_logs USING btree (severidade);


--
-- Name: index_error_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_error_logs_on_user_id ON public.error_logs USING btree (user_id);


--
-- Name: index_evento_membros_on_evento_id_and_member_id_and_papel; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_evento_membros_on_evento_id_and_member_id_and_papel ON public.evento_membros USING btree (evento_id, member_id, papel);


--
-- Name: index_evento_membros_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evento_membros_on_member_id ON public.evento_membros USING btree (member_id);


--
-- Name: index_eventos_on_data_inicio; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_eventos_on_data_inicio ON public.eventos USING btree (data_inicio);


--
-- Name: index_gestoes_on_ano_inicio; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gestoes_on_ano_inicio ON public.gestoes USING btree (ano_inicio);


--
-- Name: index_ideias_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ideias_on_status ON public.ideias USING btree (status);


--
-- Name: index_ideias_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ideias_on_tipo ON public.ideias USING btree (tipo);


--
-- Name: index_ideias_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ideias_on_user_id ON public.ideias USING btree (user_id);


--
-- Name: index_itens_carrinho_on_carrinho_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_itens_carrinho_on_carrinho_id ON public.itens_carrinho USING btree (carrinho_id);


--
-- Name: index_itens_carrinho_on_produto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_itens_carrinho_on_produto_id ON public.itens_carrinho USING btree (produto_id);


--
-- Name: index_itens_carrinho_on_variante_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_itens_carrinho_on_variante_id ON public.itens_carrinho USING btree (variante_id);


--
-- Name: index_itenscarr_on_carr_prod_var; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_itenscarr_on_carr_prod_var ON public.itens_carrinho USING btree (carrinho_id, produto_id, variante_id);


--
-- Name: index_mandatos_on_cargo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mandatos_on_cargo ON public.mandatos USING btree (cargo);


--
-- Name: index_mandatos_on_diretoria_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mandatos_on_diretoria_id ON public.mandatos USING btree (diretoria_id);


--
-- Name: index_mandatos_on_gestao_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mandatos_on_gestao_id ON public.mandatos USING btree (gestao_id);


--
-- Name: index_mandatos_on_member_id_and_gestao_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_mandatos_on_member_id_and_gestao_id ON public.mandatos USING btree (member_id, gestao_id);


--
-- Name: index_members_on_padrinho_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_members_on_padrinho_id ON public.members USING btree (padrinho_id);


--
-- Name: index_members_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_members_on_user_id ON public.members USING btree (user_id);


--
-- Name: index_noticed_events_on_record; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_noticed_events_on_record ON public.noticed_events USING btree (record_type, record_id);


--
-- Name: index_noticed_notifications_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_noticed_notifications_on_event_id ON public.noticed_notifications USING btree (event_id);


--
-- Name: index_noticed_notifications_on_recipient; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_noticed_notifications_on_recipient ON public.noticed_notifications USING btree (recipient_type, recipient_id);


--
-- Name: index_noticed_notifications_recipient_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_noticed_notifications_recipient_created ON public.noticed_notifications USING btree (recipient_type, recipient_id, created_at);


--
-- Name: index_noticed_notifications_unread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_noticed_notifications_unread ON public.noticed_notifications USING btree (recipient_type, recipient_id) WHERE (read_at IS NULL);


--
-- Name: index_notifpref_on_user_canal_cat; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifpref_on_user_canal_cat ON public.notification_preferences USING btree (user_id, canal, categoria);


--
-- Name: index_oauth_identities_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_identities_on_provider_and_uid ON public.oauth_identities USING btree (provider, uid);


--
-- Name: index_oauth_identities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_identities_on_user_id ON public.oauth_identities USING btree (user_id);


--
-- Name: index_parceiros_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parceiros_on_status ON public.parceiros USING btree (status);


--
-- Name: index_parceiros_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parceiros_on_user_id ON public.parceiros USING btree (user_id);


--
-- Name: index_parceria_leads_on_parceiro_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parceria_leads_on_parceiro_id ON public.parceria_leads USING btree (parceiro_id);


--
-- Name: index_parceria_leads_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parceria_leads_on_status ON public.parceria_leads USING btree (status);


--
-- Name: index_posts_on_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_published_at ON public.posts USING btree (published_at);


--
-- Name: index_posts_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_status ON public.posts USING btree (status);


--
-- Name: index_posts_on_tipo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_tipo ON public.posts USING btree (tipo);


--
-- Name: index_posts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_posts_on_user_id ON public.posts USING btree (user_id);


--
-- Name: index_produtos_on_modo_venda; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_produtos_on_modo_venda ON public.produtos USING btree (modo_venda);


--
-- Name: index_produtos_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_produtos_on_status ON public.produtos USING btree (status);


--
-- Name: index_projeto_tecnologias_on_projeto_id_and_tecnologia_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projeto_tecnologias_on_projeto_id_and_tecnologia_id ON public.projeto_tecnologias USING btree (projeto_id, tecnologia_id);


--
-- Name: index_projeto_tecnologias_on_tecnologia_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projeto_tecnologias_on_tecnologia_id ON public.projeto_tecnologias USING btree (tecnologia_id);


--
-- Name: index_push_subscriptions_on_endpoint; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_push_subscriptions_on_endpoint ON public.push_subscriptions USING btree (endpoint);


--
-- Name: index_push_subscriptions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_push_subscriptions_on_user_id ON public.push_subscriptions USING btree (user_id);


--
-- Name: index_reservas_on_pedido_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservas_on_pedido_id ON public.reservas USING btree (pedido_id);


--
-- Name: index_reservas_on_produto_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservas_on_produto_status ON public.reservas USING btree (produto_id, status);


--
-- Name: index_reservas_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservas_on_user_id ON public.reservas USING btree (user_id);


--
-- Name: index_reservas_on_variante_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservas_on_variante_id ON public.reservas USING btree (variante_id);


--
-- Name: index_tecnologias_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tecnologias_on_nome ON public.tecnologias USING btree (nome);


--
-- Name: index_temas_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_temas_on_nome ON public.temas USING btree (nome);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_variantes_on_produto_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_variantes_on_produto_id ON public.variantes USING btree (produto_id);


--
-- Name: index_variantes_on_sku; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_variantes_on_sku ON public.variantes USING btree (sku) WHERE (sku IS NOT NULL);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: artigo_temas artigo_temas_max; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER artigo_temas_max BEFORE INSERT ON public.artigo_temas FOR EACH ROW EXECUTE FUNCTION public.trg_artigo_temas_max();


--
-- Name: produtos produto_indisponivel_after; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER produto_indisponivel_after AFTER UPDATE OF status ON public.produtos FOR EACH ROW EXECUTE FUNCTION public.trg_produto_indisponivel();


--
-- Name: reservas fk_rails_07332f38c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT fk_rails_07332f38c1 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: convidados fk_rails_08fae7ff70; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.convidados
    ADD CONSTRAINT fk_rails_08fae7ff70 FOREIGN KEY (evento_id) REFERENCES public.eventos(id) ON DELETE CASCADE;


--
-- Name: members fk_rails_1848f16cd8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT fk_rails_1848f16cd8 FOREIGN KEY (padrinho_id) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: posts fk_rails_1bc159f2b6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_1bc159f2b6 FOREIGN KEY (approved_by) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: autores fk_rails_1bedd4e7e7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.autores
    ADD CONSTRAINT fk_rails_1bedd4e7e7 FOREIGN KEY (artigo_id) REFERENCES public.artigos(id) ON DELETE CASCADE;


--
-- Name: members fk_rails_2e88fb7ce9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT fk_rails_2e88fb7ce9 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: oauth_identities fk_rails_2f75762ff1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities
    ADD CONSTRAINT fk_rails_2f75762ff1 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: artigo_temas fk_rails_2f7d23d9ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artigo_temas
    ADD CONSTRAINT fk_rails_2f7d23d9ee FOREIGN KEY (tema_id) REFERENCES public.temas(id) ON DELETE CASCADE;


--
-- Name: reservas fk_rails_3684009d8d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT fk_rails_3684009d8d FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE RESTRICT;


--
-- Name: acoes fk_rails_38f7189c12; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acoes
    ADD CONSTRAINT fk_rails_38f7189c12 FOREIGN KEY (ideia_id) REFERENCES public.ideias(id) ON DELETE SET NULL;


--
-- Name: denuncias fk_rails_3dd1374548; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denuncias
    ADD CONSTRAINT fk_rails_3dd1374548 FOREIGN KEY (comentario_id) REFERENCES public.comentarios(id) ON DELETE CASCADE;


--
-- Name: itens_carrinho fk_rails_401249fe28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_carrinho
    ADD CONSTRAINT fk_rails_401249fe28 FOREIGN KEY (variante_id) REFERENCES public.variantes(id) ON DELETE SET NULL;


--
-- Name: contribuicoes fk_rails_4043761945; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes
    ADD CONSTRAINT fk_rails_4043761945 FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: denuncias fk_rails_40b2bc54f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denuncias
    ADD CONSTRAINT fk_rails_40b2bc54f9 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: convidado_links fk_rails_42b3d2b040; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.convidado_links
    ADD CONSTRAINT fk_rails_42b3d2b040 FOREIGN KEY (convidado_id) REFERENCES public.convidados(id) ON DELETE CASCADE;


--
-- Name: acao_parceiros fk_rails_43cea40678; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acao_parceiros
    ADD CONSTRAINT fk_rails_43cea40678 FOREIGN KEY (acao_id) REFERENCES public.acoes(id) ON DELETE CASCADE;


--
-- Name: push_subscriptions fk_rails_43d43720fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT fk_rails_43d43720fc FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: evento_membros fk_rails_4aff658e44; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_membros
    ADD CONSTRAINT fk_rails_4aff658e44 FOREIGN KEY (evento_id) REFERENCES public.eventos(id) ON DELETE CASCADE;


--
-- Name: itens_carrinho fk_rails_5442124134; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_carrinho
    ADD CONSTRAINT fk_rails_5442124134 FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;


--
-- Name: analytics_events fk_rails_5b319ff5df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.analytics_events
    ADD CONSTRAINT fk_rails_5b319ff5df FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: posts fk_rails_5b5ddfd518; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT fk_rails_5b5ddfd518 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: comentarios fk_rails_5d4ddb7416; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios
    ADD CONSTRAINT fk_rails_5d4ddb7416 FOREIGN KEY (post_id) REFERENCES public.posts(id) ON DELETE CASCADE;


--
-- Name: autores fk_rails_633dbf1289; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.autores
    ADD CONSTRAINT fk_rails_633dbf1289 FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: comentarios fk_rails_644fc17ed7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios
    ADD CONSTRAINT fk_rails_644fc17ed7 FOREIGN KEY (moderated_by) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: projeto_tecnologias fk_rails_6da1aaeee2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_tecnologias
    ADD CONSTRAINT fk_rails_6da1aaeee2 FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: parceria_leads fk_rails_7035ff8157; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parceria_leads
    ADD CONSTRAINT fk_rails_7035ff8157 FOREIGN KEY (parceiro_id) REFERENCES public.parceiros(id) ON DELETE SET NULL;


--
-- Name: carrinhos fk_rails_73de8bf3f2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.carrinhos
    ADD CONSTRAINT fk_rails_73de8bf3f2 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: apresentacoes fk_rails_792f2a0778; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apresentacoes
    ADD CONSTRAINT fk_rails_792f2a0778 FOREIGN KEY (congresso_id) REFERENCES public.congressos(id) ON DELETE RESTRICT;


--
-- Name: ideias fk_rails_7e7dc50700; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideias
    ADD CONSTRAINT fk_rails_7e7dc50700 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: reservas fk_rails_7eac5e645e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservas
    ADD CONSTRAINT fk_rails_7eac5e645e FOREIGN KEY (variante_id) REFERENCES public.variantes(id) ON DELETE SET NULL;


--
-- Name: produtos fk_rails_8563f0e618; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.produtos
    ADD CONSTRAINT fk_rails_8563f0e618 FOREIGN KEY (created_by) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: itens_carrinho fk_rails_91c14758da; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.itens_carrinho
    ADD CONSTRAINT fk_rails_91c14758da FOREIGN KEY (carrinho_id) REFERENCES public.carrinhos(id) ON DELETE CASCADE;


--
-- Name: notification_preferences fk_rails_9503aade25; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT fk_rails_9503aade25 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: projeto_tecnologias fk_rails_9b24c9a8a2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_tecnologias
    ADD CONSTRAINT fk_rails_9b24c9a8a2 FOREIGN KEY (tecnologia_id) REFERENCES public.tecnologias(id) ON DELETE CASCADE;


--
-- Name: ideias fk_rails_a21b374619; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ideias
    ADD CONSTRAINT fk_rails_a21b374619 FOREIGN KEY (reviewed_by) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: error_logs fk_rails_a23f9ccaf8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.error_logs
    ADD CONSTRAINT fk_rails_a23f9ccaf8 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: comentarios fk_rails_ba3fc881e1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comentarios
    ADD CONSTRAINT fk_rails_ba3fc881e1 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: cookie_consents fk_rails_bed9808f1f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cookie_consents
    ADD CONSTRAINT fk_rails_bed9808f1f FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: variantes fk_rails_bfeae8e22c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.variantes
    ADD CONSTRAINT fk_rails_bfeae8e22c FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE;


--
-- Name: acao_parceiros fk_rails_c06ff30b28; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acao_parceiros
    ADD CONSTRAINT fk_rails_c06ff30b28 FOREIGN KEY (parceiro_id) REFERENCES public.parceiros(id) ON DELETE CASCADE;


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: acoes fk_rails_caab47dca1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acoes
    ADD CONSTRAINT fk_rails_caab47dca1 FOREIGN KEY (created_by) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: mandatos fk_rails_cc3407d2c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos
    ADD CONSTRAINT fk_rails_cc3407d2c8 FOREIGN KEY (gestao_id) REFERENCES public.gestoes(id) ON DELETE RESTRICT;


--
-- Name: artigo_temas fk_rails_ce9cd5773d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artigo_temas
    ADD CONSTRAINT fk_rails_ce9cd5773d FOREIGN KEY (artigo_id) REFERENCES public.artigos(id) ON DELETE CASCADE;


--
-- Name: contribuicoes fk_rails_cf67cdf227; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes
    ADD CONSTRAINT fk_rails_cf67cdf227 FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: denuncias fk_rails_e0436d9b54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.denuncias
    ADD CONSTRAINT fk_rails_e0436d9b54 FOREIGN KEY (resolved_by) REFERENCES public.members(id) ON DELETE SET NULL;


--
-- Name: mandatos fk_rails_ea23ad2fbc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos
    ADD CONSTRAINT fk_rails_ea23ad2fbc FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: apresentacoes fk_rails_ec8f774d5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.apresentacoes
    ADD CONSTRAINT fk_rails_ec8f774d5b FOREIGN KEY (artigo_id) REFERENCES public.artigos(id) ON DELETE CASCADE;


--
-- Name: mandatos fk_rails_f5a206f86f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos
    ADD CONSTRAINT fk_rails_f5a206f86f FOREIGN KEY (diretoria_id) REFERENCES public.diretorias(id) ON DELETE SET NULL;


--
-- Name: evento_membros fk_rails_fa54a66cb7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evento_membros
    ADD CONSTRAINT fk_rails_fa54a66cb7 FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: parceiros fk_rails_fa996bf0d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parceiros
    ADD CONSTRAINT fk_rails_fa996bf0d1 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260709050000'),
('20260709040000'),
('20260709030000'),
('20260709020000'),
('20260709010000'),
('20260708232202'),
('20260708232201'),
('20260708232200'),
('20260708232158'),
('20260708232157'),
('20260708010001'),
('20260708010000'),
('20260706010000'),
('20260705150000'),
('20260705140003'),
('20260705040008'),
('20260705040007'),
('20260705040006'),
('20260705040005'),
('20260705040004'),
('20260705040003'),
('20260705040002'),
('20260705040001'),
('20260705040000'),
('20260705010005'),
('20260705010004'),
('20260705010003'),
('20260705010002'),
('20260705010001'),
('20260705010000'),
('20260704060003'),
('20260704060002'),
('20260704060001'),
('20260704060000'),
('20260704045151'),
('20260704045150'),
('20260704045149');

