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


SET default_tablespace = '';

SET default_table_access_method = heap;

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
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


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
-- Name: acoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acoes ALTER COLUMN id SET DEFAULT nextval('public.acoes_id_seq'::regclass);


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
-- Name: contribuicoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes ALTER COLUMN id SET DEFAULT nextval('public.contribuicoes_id_seq'::regclass);


--
-- Name: diretorias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diretorias ALTER COLUMN id SET DEFAULT nextval('public.diretorias_id_seq'::regclass);


--
-- Name: gestoes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gestoes ALTER COLUMN id SET DEFAULT nextval('public.gestoes_id_seq'::regclass);


--
-- Name: mandatos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos ALTER COLUMN id SET DEFAULT nextval('public.mandatos_id_seq'::regclass);


--
-- Name: members id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members ALTER COLUMN id SET DEFAULT nextval('public.members_id_seq'::regclass);


--
-- Name: oauth_identities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities ALTER COLUMN id SET DEFAULT nextval('public.oauth_identities_id_seq'::regclass);


--
-- Name: projeto_tecnologias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_tecnologias ALTER COLUMN id SET DEFAULT nextval('public.projeto_tecnologias_id_seq'::regclass);


--
-- Name: projetos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projetos ALTER COLUMN id SET DEFAULT nextval('public.projetos_id_seq'::regclass);


--
-- Name: tecnologias id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tecnologias ALTER COLUMN id SET DEFAULT nextval('public.tecnologias_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions ALTER COLUMN id SET DEFAULT nextval('public.versions_id_seq'::regclass);


--
-- Name: acoes acoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.acoes
    ADD CONSTRAINT acoes_pkey PRIMARY KEY (id);


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
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: contribuicoes contribuicoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes
    ADD CONSTRAINT contribuicoes_pkey PRIMARY KEY (id);


--
-- Name: diretorias diretorias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diretorias
    ADD CONSTRAINT diretorias_pkey PRIMARY KEY (id);


--
-- Name: gestoes gestoes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gestoes
    ADD CONSTRAINT gestoes_pkey PRIMARY KEY (id);


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
-- Name: oauth_identities oauth_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_identities
    ADD CONSTRAINT oauth_identities_pkey PRIMARY KEY (id);


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
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: versions versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.versions
    ADD CONSTRAINT versions_pkey PRIMARY KEY (id);


--
-- Name: index_acoes_on_detalhe_type_and_detalhe_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_acoes_on_detalhe_type_and_detalhe_id ON public.acoes USING btree (detalhe_type, detalhe_id);


--
-- Name: index_acoes_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_acoes_on_status ON public.acoes USING btree (status);


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
-- Name: index_contribuicoes_on_member_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_contribuicoes_on_member_id ON public.contribuicoes USING btree (member_id);


--
-- Name: index_contribuicoes_on_projeto_id_and_member_id_and_papel; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_contribuicoes_on_projeto_id_and_member_id_and_papel ON public.contribuicoes USING btree (projeto_id, member_id, papel);


--
-- Name: index_diretorias_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_diretorias_on_nome ON public.diretorias USING btree (nome);


--
-- Name: index_gestoes_on_ano_inicio; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_gestoes_on_ano_inicio ON public.gestoes USING btree (ano_inicio);


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
-- Name: index_oauth_identities_on_provider_and_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oauth_identities_on_provider_and_uid ON public.oauth_identities USING btree (provider, uid);


--
-- Name: index_oauth_identities_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oauth_identities_on_user_id ON public.oauth_identities USING btree (user_id);


--
-- Name: index_projeto_tecnologias_on_projeto_id_and_tecnologia_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projeto_tecnologias_on_projeto_id_and_tecnologia_id ON public.projeto_tecnologias USING btree (projeto_id, tecnologia_id);


--
-- Name: index_projeto_tecnologias_on_tecnologia_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projeto_tecnologias_on_tecnologia_id ON public.projeto_tecnologias USING btree (tecnologia_id);


--
-- Name: index_tecnologias_on_nome; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_tecnologias_on_nome ON public.tecnologias USING btree (nome);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_versions_on_item_type_and_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_versions_on_item_type_and_item_id ON public.versions USING btree (item_type, item_id);


--
-- Name: members fk_rails_1848f16cd8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.members
    ADD CONSTRAINT fk_rails_1848f16cd8 FOREIGN KEY (padrinho_id) REFERENCES public.members(id) ON DELETE SET NULL;


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
-- Name: contribuicoes fk_rails_4043761945; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes
    ADD CONSTRAINT fk_rails_4043761945 FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: projeto_tecnologias fk_rails_6da1aaeee2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projeto_tecnologias
    ADD CONSTRAINT fk_rails_6da1aaeee2 FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


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
-- Name: contribuicoes fk_rails_cf67cdf227; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contribuicoes
    ADD CONSTRAINT fk_rails_cf67cdf227 FOREIGN KEY (projeto_id) REFERENCES public.projetos(id) ON DELETE CASCADE;


--
-- Name: mandatos fk_rails_ea23ad2fbc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos
    ADD CONSTRAINT fk_rails_ea23ad2fbc FOREIGN KEY (member_id) REFERENCES public.members(id) ON DELETE CASCADE;


--
-- Name: mandatos fk_rails_f5a206f86f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mandatos
    ADD CONSTRAINT fk_rails_f5a206f86f FOREIGN KEY (diretoria_id) REFERENCES public.diretorias(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
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

