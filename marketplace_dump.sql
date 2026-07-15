--
-- PostgreSQL database dump
--

\restrict 9CkakTxGTzZKfazMzhooEHAHhqkVio7eZPfsceqt6S2Y2Hb5KMw3ElGDgmQ1B1U

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

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
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: is_url_whitelisted(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_url_whitelisted(p_url text) RETURNS TABLE(is_whitelisted boolean, marketplace_name text, category text)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        TRUE,
        m.name::TEXT,
        mc.label::TEXT
    FROM marketplace_url mu
    JOIN marketplace m  ON m.id  = mu.marketplace_id
    JOIN marketplace_category mc ON mc.id = m.category_id
    WHERE mu.url = p_url AND mu.is_verified = TRUE AND m.is_active = TRUE
    LIMIT 1;
$$;


ALTER FUNCTION public.is_url_whitelisted(p_url text) OWNER TO postgres;

--
-- Name: trg_set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.trg_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;


ALTER FUNCTION public.trg_set_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: marketplace; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marketplace (
    id integer NOT NULL,
    name character varying(128) NOT NULL,
    category_id integer CONSTRAINT marketplace_category_id_not_null1 NOT NULL,
    hq_country character(2),
    founded_year smallint,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.marketplace OWNER TO postgres;

--
-- Name: marketplace_category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marketplace_category (
    id integer NOT NULL,
    slug character varying(64) NOT NULL,
    label character varying(128) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.marketplace_category OWNER TO postgres;

--
-- Name: marketplace_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.marketplace_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.marketplace_category_id_seq OWNER TO postgres;

--
-- Name: marketplace_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.marketplace_category_id_seq OWNED BY public.marketplace_category.id;


--
-- Name: marketplace_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.marketplace_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.marketplace_id_seq OWNER TO postgres;

--
-- Name: marketplace_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.marketplace_id_seq OWNED BY public.marketplace.id;


--
-- Name: marketplace_url; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marketplace_url (
    id bigint NOT NULL,
    marketplace_id integer NOT NULL,
    url text NOT NULL,
    url_type character varying(32) DEFAULT 'root'::character varying NOT NULL,
    protocol character varying(8) DEFAULT 'https'::character varying NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    is_verified boolean DEFAULT true NOT NULL,
    verified_at timestamp with time zone,
    notes text,
    added_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT marketplace_url_protocol_check CHECK (((protocol)::text = ANY ((ARRAY['https'::character varying, 'http'::character varying, 'wss'::character varying])::text[]))),
    CONSTRAINT marketplace_url_url_type_check CHECK (((url_type)::text = ANY ((ARRAY['root'::character varying, 'subdomain'::character varying, 'app'::character varying, 'api'::character varying, 'cdn'::character varying, 'help'::character varying, 'mobile'::character varying])::text[])))
);


ALTER TABLE public.marketplace_url OWNER TO postgres;

--
-- Name: marketplace_url_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.marketplace_url_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.marketplace_url_id_seq OWNER TO postgres;

--
-- Name: marketplace_url_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.marketplace_url_id_seq OWNED BY public.marketplace_url.id;


--
-- Name: trust_signal; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.trust_signal (
    id integer NOT NULL,
    marketplace_id integer NOT NULL,
    signal_type character varying(64),
    issuer character varying(128),
    valid_until date,
    source_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.trust_signal OWNER TO postgres;

--
-- Name: trust_signal_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.trust_signal_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.trust_signal_id_seq OWNER TO postgres;

--
-- Name: trust_signal_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.trust_signal_id_seq OWNED BY public.trust_signal.id;


--
-- Name: url_alias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.url_alias (
    id bigint NOT NULL,
    alias_url text NOT NULL,
    canonical_url_id bigint NOT NULL,
    alias_type character varying(32) DEFAULT 'redirect'::character varying,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT url_alias_alias_type_check CHECK (((alias_type)::text = ANY ((ARRAY['redirect'::character varying, 'short_link'::character varying, 'regional'::character varying, 'deprecated'::character varying])::text[])))
);


ALTER TABLE public.url_alias OWNER TO postgres;

--
-- Name: url_alias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.url_alias_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.url_alias_id_seq OWNER TO postgres;

--
-- Name: url_alias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.url_alias_id_seq OWNED BY public.url_alias.id;


--
-- Name: v_whitelist_full; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_whitelist_full AS
 SELECT mu.url,
    mu.url_type,
    mu.protocol,
    mu.is_primary,
    mu.is_verified,
    m.name AS marketplace_name,
    mc.label AS category,
    m.hq_country,
    m.founded_year,
    mu.added_at
   FROM ((public.marketplace_url mu
     JOIN public.marketplace m ON ((m.id = mu.marketplace_id)))
     JOIN public.marketplace_category mc ON ((mc.id = m.category_id)))
  WHERE ((mu.is_verified = true) AND (m.is_active = true))
  ORDER BY mc.slug, m.name, mu.is_primary DESC;


ALTER VIEW public.v_whitelist_full OWNER TO postgres;

--
-- Name: whitelist_audit_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.whitelist_audit_log (
    id bigint NOT NULL,
    action character varying(16) NOT NULL,
    table_name character varying(64),
    record_id bigint,
    changed_by character varying(128),
    note text,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT whitelist_audit_log_action_check CHECK (((action)::text = ANY ((ARRAY['INSERT'::character varying, 'UPDATE'::character varying, 'DELETE'::character varying, 'VERIFY'::character varying, 'FLAG'::character varying])::text[])))
);


ALTER TABLE public.whitelist_audit_log OWNER TO postgres;

--
-- Name: whitelist_audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.whitelist_audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.whitelist_audit_log_id_seq OWNER TO postgres;

--
-- Name: whitelist_audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.whitelist_audit_log_id_seq OWNED BY public.whitelist_audit_log.id;


--
-- Name: marketplace id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace ALTER COLUMN id SET DEFAULT nextval('public.marketplace_id_seq'::regclass);


--
-- Name: marketplace_category id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace_category ALTER COLUMN id SET DEFAULT nextval('public.marketplace_category_id_seq'::regclass);


--
-- Name: marketplace_url id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace_url ALTER COLUMN id SET DEFAULT nextval('public.marketplace_url_id_seq'::regclass);


--
-- Name: trust_signal id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trust_signal ALTER COLUMN id SET DEFAULT nextval('public.trust_signal_id_seq'::regclass);


--
-- Name: url_alias id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.url_alias ALTER COLUMN id SET DEFAULT nextval('public.url_alias_id_seq'::regclass);


--
-- Name: whitelist_audit_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.whitelist_audit_log ALTER COLUMN id SET DEFAULT nextval('public.whitelist_audit_log_id_seq'::regclass);


--
-- Data for Name: marketplace; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marketplace (id, name, category_id, hq_country, founded_year, is_active, notes, created_at, updated_at) FROM stdin;
1	Amazon	1	US	1994	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
2	eBay	1	US	1995	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
3	Walmart	1	US	1962	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
4	Target	1	US	1902	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
5	AliExpress	1	CN	2010	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
6	Taobao	1	CN	2003	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
7	Tmall	1	CN	2008	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
8	JD.com	1	CN	1998	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
9	Flipkart	1	IN	2007	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
10	Meesho	1	IN	2015	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
11	Shopee	1	SG	2015	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
12	Lazada	1	SG	2012	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
13	Rakuten	1	JP	1997	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
14	Mercado Libre	1	AR	1999	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
15	Temu	1	CN	2022	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
16	Wish	1	US	2010	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
17	Jumia	1	NG	2012	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
18	Noon	1	AE	2017	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
19	Allegro	1	PL	1999	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
20	Otto	1	DE	1949	t	\N	2026-07-15 09:46:31.856431+05:30	2026-07-15 09:46:31.856431+05:30
21	ASOS	2	GB	2000	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
22	Zalando	2	DE	2008	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
23	Zara	2	ES	1974	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
24	H&M	2	SE	1947	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
25	Shein	2	CN	2008	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
26	Depop	2	GB	2011	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
27	Vinted	2	LT	2008	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
28	Poshmark	2	US	2011	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
29	The RealReal	2	US	2011	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
30	Vestiaire Collective	2	FR	2009	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
31	Myntra	2	IN	2007	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
32	Nykaa Fashion	2	IN	2012	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
33	SSENSE	2	CA	2000	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
34	Farfetch	2	GB	2007	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
35	Net-a-Porter	2	GB	2000	t	\N	2026-07-15 09:46:31.871381+05:30	2026-07-15 09:46:31.871381+05:30
36	Newegg	3	US	2001	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
37	Best Buy	3	US	1966	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
38	B&H Photo	3	US	1973	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
39	Adorama	3	US	1975	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
40	MediaMarkt	3	DE	1979	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
41	Currys	3	GB	1884	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
42	Croma	3	IN	2006	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
43	Vijay Sales	3	IN	1967	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
44	Cdiscount	3	FR	1998	t	\N	2026-07-15 09:46:31.873771+05:30	2026-07-15 09:46:31.873771+05:30
45	Steam	4	US	2003	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
46	Epic Games Store	4	US	2018	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
47	GOG.com	4	PL	2008	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
48	Humble Bundle	4	US	2010	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
49	Fanatical	4	GB	2012	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
50	Green Man Gaming	4	GB	2009	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
51	Bandcamp	4	US	2007	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
52	Gumroad	4	US	2011	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
53	Itch.io	4	US	2013	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
54	Envato Market	4	AU	2006	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
55	Creative Market	4	US	2012	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
56	AppSumo	4	US	2010	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
57	StackSocial	4	US	2011	t	\N	2026-07-15 09:46:31.875535+05:30	2026-07-15 09:46:31.875535+05:30
58	Etsy	5	US	2005	t	\N	2026-07-15 09:46:31.877503+05:30	2026-07-15 09:46:31.877503+05:30
59	Artfire	5	US	2008	t	\N	2026-07-15 09:46:31.877503+05:30	2026-07-15 09:46:31.877503+05:30
60	Folksy	5	GB	2008	t	\N	2026-07-15 09:46:31.877503+05:30	2026-07-15 09:46:31.877503+05:30
61	Zibbet	5	AU	2009	t	\N	2026-07-15 09:46:31.877503+05:30	2026-07-15 09:46:31.877503+05:30
62	Storenvy	5	US	2010	t	\N	2026-07-15 09:46:31.877503+05:30	2026-07-15 09:46:31.877503+05:30
63	DaWanda	5	DE	2006	t	\N	2026-07-15 09:46:31.877503+05:30	2026-07-15 09:46:31.877503+05:30
64	Alibaba.com	6	CN	1999	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
65	Global Sources	6	HK	1971	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
66	Made-in-China	6	CN	1998	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
67	IndiaMART	6	IN	1999	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
68	TradeIndia	6	IN	2000	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
69	ThomasNet	6	US	1898	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
70	Faire	6	US	2017	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
71	Angi (Angie's List)	6	US	1995	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
72	Tundra	6	US	2017	t	\N	2026-07-15 09:46:31.881965+05:30	2026-07-15 09:46:31.881965+05:30
73	Craigslist	7	US	1995	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
74	Gumtree	7	GB	2000	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
75	OLX	7	NL	2006	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
76	Quikr	7	IN	2008	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
77	Facebook Marketplace	7	US	2016	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
78	Nextdoor	7	US	2011	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
79	Wallapop	7	ES	2013	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
80	Leboncoin	7	FR	2006	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
81	Kleinanzeigen	7	DE	2009	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
82	Marktplaats	7	NL	1999	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
83	Catawiki	7	NL	2008	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
84	Invaluable	7	US	1989	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
85	Bonanza	7	US	2007	t	\N	2026-07-15 09:46:31.883527+05:30	2026-07-15 09:46:31.883527+05:30
86	Booking.com	8	NL	1996	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
87	Airbnb	8	US	2008	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
88	Expedia	8	US	1996	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
89	Vrbo	8	US	1995	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
90	TripAdvisor	8	US	2000	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
91	Kayak	8	US	2004	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
92	Skyscanner	8	GB	2003	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
93	Hotels.com	8	US	1991	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
94	Trivago	8	DE	2005	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
95	GetYourGuide	8	DE	2009	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
96	Viator	8	US	1999	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
97	Hostelworld	8	IE	1999	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
98	MakeMyTrip	8	IN	2000	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
99	Cleartrip	8	IN	2006	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
100	Yatra	8	IN	2006	t	\N	2026-07-15 09:46:31.88571+05:30	2026-07-15 09:46:31.88571+05:30
101	DoorDash	9	US	2013	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
102	Uber Eats	9	US	2014	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
103	Grubhub	9	US	2004	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
104	Instacart	9	US	2012	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
105	Deliveroo	9	GB	2013	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
106	Just Eat	9	GB	2001	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
107	Takeaway.com	9	NL	2000	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
108	Zomato	9	IN	2008	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
109	Swiggy	9	IN	2014	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
110	Rappi	9	CO	2015	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
111	iFood	9	BR	2011	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
112	Meituan	9	CN	2010	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
113	Talabat	9	KW	2004	t	\N	2026-07-15 09:46:31.887424+05:30	2026-07-15 09:46:31.887424+05:30
114	Uber	10	US	2009	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
115	Lyft	10	US	2012	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
116	Ola	10	IN	2010	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
117	Grab	10	SG	2012	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
118	DiDi	10	CN	2012	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
119	Bolt	10	EE	2013	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
120	Yandex Taxi	10	RU	2011	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
121	inDriver	10	RU	2012	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
122	Gett	10	IL	2010	t	\N	2026-07-15 09:46:31.890495+05:30	2026-07-15 09:46:31.890495+05:30
123	Fiverr	11	IL	2010	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
124	Upwork	11	US	1998	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
125	Toptal	11	US	2010	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
126	Freelancer.com	11	AU	2009	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
127	PeoplePerHour	11	GB	2007	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
128	Guru.com	11	US	1998	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
129	99designs	11	AU	2008	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
130	TaskRabbit	11	US	2008	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
131	Bark.com	11	GB	2014	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
132	Workana	11	AR	2012	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
133	Urban Company	11	IN	2014	t	\N	2026-07-15 09:46:31.892803+05:30	2026-07-15 09:46:31.892803+05:30
134	Zillow	12	US	2006	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
135	Realtor.com	12	US	1996	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
136	Redfin	12	US	2004	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
137	Rightmove	12	GB	2000	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
138	Zoopla	12	GB	2008	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
139	Immobilienscout24	12	DE	1998	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
140	MagicBricks	12	IN	2006	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
141	99acres	12	IN	2005	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
142	Housing.com	12	IN	2012	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
143	SeLoger	12	FR	1992	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
144	Domain	12	AU	2004	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
145	REA Group	12	AU	1995	t	\N	2026-07-15 09:46:31.897016+05:30	2026-07-15 09:46:31.897016+05:30
146	AutoTrader	13	US	1997	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
147	Cars.com	13	US	1998	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
148	CarGurus	13	US	2006	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
149	Carvana	13	US	2012	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
150	Vroom	13	US	2013	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
151	AutoScout24	13	DE	1998	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
152	mobile.de	13	DE	1996	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
153	CarDekho	13	IN	2008	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
154	CarWale	13	IN	2005	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
155	BikeDekho	13	IN	2009	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
156	Cazoo	13	GB	2018	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
157	AA Cars	13	GB	2014	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
158	Carsales	13	AU	1997	t	\N	2026-07-15 09:46:31.900088+05:30	2026-07-15 09:46:31.900088+05:30
159	Coursera	14	US	2012	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
160	Udemy	14	US	2010	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
161	edX	14	US	2012	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
162	Skillshare	14	US	2010	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
163	Chegg	14	US	2005	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
164	ThriftBooks	14	US	2003	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
165	AbeBooks	14	CA	1996	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
166	Book Depository	14	GB	2004	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
167	Audible	14	US	1995	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
168	Scribd	14	US	2007	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
169	Byjus	14	IN	2011	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
170	Unacademy	14	IN	2010	t	\N	2026-07-15 09:46:31.902127+05:30	2026-07-15 09:46:31.902127+05:30
171	iHerb	15	US	1996	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
172	Vitacost	15	US	1994	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
173	LookFantastic	15	GB	2001	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
174	Nykaa	15	IN	2012	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
175	Chemist Direct	15	GB	2006	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
176	Netmeds	15	IN	2010	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
177	PharmEasy	15	IN	2015	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
178	Wellness Forever	15	IN	2008	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
179	Cult.fit	15	IN	2016	t	\N	2026-07-15 09:46:31.904117+05:30	2026-07-15 09:46:31.904117+05:30
\.


--
-- Data for Name: marketplace_category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marketplace_category (id, slug, label, description, created_at) FROM stdin;
1	ecommerce	General E-Commerce	Multi-category retail marketplaces	2026-07-15 09:46:31.706705+05:30
2	fashion	Fashion & Apparel	Clothing, footwear, accessories	2026-07-15 09:46:31.706705+05:30
3	electronics	Electronics & Tech	Gadgets, computers, software	2026-07-15 09:46:31.706705+05:30
4	digital_goods	Digital Goods	Software, games, media, subscriptions	2026-07-15 09:46:31.706705+05:30
5	handmade	Handmade & Crafts	Artisan and independent creator goods	2026-07-15 09:46:31.706705+05:30
6	b2b	B2B / Wholesale	Business-to-business procurement platforms	2026-07-15 09:46:31.706705+05:30
7	classifieds	Classifieds & Auctions	Peer-to-peer listings and auctions	2026-07-15 09:46:31.706705+05:30
8	travel	Travel & Accommodation	Flights, hotels, holiday rentals	2026-07-15 09:46:31.706705+05:30
9	food_delivery	Food & Grocery Delivery	Restaurant and grocery ordering	2026-07-15 09:46:31.706705+05:30
10	ride_hailing	Ride-hailing & Mobility	Taxi, e-scooter, bike-share	2026-07-15 09:46:31.706705+05:30
11	freelance	Freelance & Services	Gig economy and professional services	2026-07-15 09:46:31.706705+05:30
12	real_estate	Real Estate	Property sales and rentals	2026-07-15 09:46:31.706705+05:30
13	automotive	Automotive	Car sales, parts, leasing	2026-07-15 09:46:31.706705+05:30
14	books_education	Books & Education	Textbooks, courses, learning platforms	2026-07-15 09:46:31.706705+05:30
15	health_beauty	Health & Beauty	Pharmacy, personal care, cosmetics	2026-07-15 09:46:31.706705+05:30
16	financial	Financial Services	Banking, insurance, payments	2026-07-15 09:46:31.706705+05:30
17	crypto	Crypto / Web3	NFT, DEX, token launchpads	2026-07-15 09:46:31.706705+05:30
\.


--
-- Data for Name: marketplace_url; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marketplace_url (id, marketplace_id, url, url_type, protocol, is_primary, is_verified, verified_at, notes, added_at) FROM stdin;
1	1	https://www.amazon.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
2	1	https://www.amazon.co.uk	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
3	1	https://www.amazon.de	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
4	1	https://www.amazon.co.jp	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
5	1	https://www.amazon.in	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
6	1	https://www.amazon.fr	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
7	1	https://www.amazon.ca	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
8	1	https://www.amazon.com.au	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
9	1	https://www.amazon.com.br	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
10	1	https://www.amazon.com.mx	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
11	1	https://www.amazon.es	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
12	1	https://www.amazon.it	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
13	1	https://m.amazon.com	mobile	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
14	1	https://smile.amazon.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
15	1	https://aws.amazon.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
16	2	https://www.ebay.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
17	2	https://www.ebay.co.uk	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
18	2	https://www.ebay.de	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
19	2	https://www.ebay.com.au	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
20	2	https://www.ebay.in	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
21	2	https://www.ebay.fr	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
22	2	https://www.ebay.it	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
23	2	https://www.ebay.es	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
24	2	https://www.ebay.ca	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
25	2	https://www.ebay.nl	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
26	5	https://www.aliexpress.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
27	5	https://www.aliexpress.us	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
28	5	https://www.aliexpress.ru	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
29	5	https://m.aliexpress.com	mobile	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
30	9	https://www.flipkart.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
31	9	https://dl.flipkart.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
32	9	https://m.flipkart.com	mobile	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
33	9	https://seller.flipkart.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
34	10	https://meesho.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
35	10	https://www.meesho.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
36	10	https://supplier.meesho.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
37	11	https://shopee.sg	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
38	11	https://shopee.com.my	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
39	11	https://shopee.co.id	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
40	11	https://shopee.co.th	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
41	11	https://shopee.vn	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
42	11	https://shopee.ph	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
43	11	https://shopee.com.br	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
44	58	https://www.etsy.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
45	58	https://m.etsy.com	mobile	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
46	58	https://sell.etsy.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
47	58	https://help.etsy.com	help	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
48	64	https://www.alibaba.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
49	64	https://seller.alibaba.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
50	64	https://m.alibaba.com	mobile	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
51	86	https://www.booking.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
52	86	https://admin.booking.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
53	86	https://partner.booking.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
54	87	https://www.airbnb.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
55	87	https://www.airbnb.co.uk	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
56	87	https://www.airbnb.in	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
57	87	https://www.airbnb.com.au	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
58	45	https://store.steampowered.com	subdomain	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
59	45	https://steamcommunity.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
60	45	https://api.steampowered.com	api	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
61	45	https://cdn.cloudflare.steamstatic.com	cdn	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
62	123	https://www.fiverr.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
63	123	https://sellers.fiverr.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
64	124	https://www.upwork.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
65	124	https://www.freelancer.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
66	159	https://www.coursera.org	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
67	159	https://www.coursera.org/professional-certificates	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
68	160	https://www.udemy.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
69	160	https://business.udemy.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
70	108	https://www.zomato.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
71	108	https://www.zomato.com/order	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
72	108	https://blog.zomato.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
73	109	https://www.swiggy.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
74	109	https://partner.swiggy.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
75	3	https://www.walmart.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
76	3	https://www.walmart.com/grocery	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
77	3	https://seller.walmart.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
78	13	https://www.rakuten.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
79	13	https://www.rakuten.co.jp	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
80	14	https://www.mercadolibre.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
81	14	https://www.mercadopago.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
82	14	https://www.mercadolibre.com.ar	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
83	14	https://www.mercadolibre.com.br	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
84	101	https://www.doordash.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
85	101	https://merchant.doordash.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
86	102	https://www.ubereats.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
87	102	https://restaurants.ubereats.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
88	114	https://www.uber.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
89	114	https://driver.uber.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
90	114	https://help.uber.com	help	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
91	116	https://www.olacabs.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
92	116	https://oladriver.app.link	app	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
93	21	https://www.asos.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
94	21	https://marketplace.asos.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
95	134	https://www.zillow.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
96	134	https://www.zillowgroup.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
97	134	https://hotpads.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
98	146	https://www.autotrader.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
99	146	https://www.autotrader.co.uk	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
100	36	https://www.newegg.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
101	36	https://www.newegg.ca	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
102	36	https://www.newegg.com.au	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
103	171	https://www.iherb.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
104	171	https://m.iherb.com	mobile	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
105	174	https://www.nykaa.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
106	174	https://www.nykaaman.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
107	174	https://www.nykaabeauty.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
108	177	https://pharmeasy.in	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
109	177	https://api.pharmeasy.in	api	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
110	67	https://www.indiamart.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
111	67	https://seller.indiamart.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
112	76	https://www.quikr.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
113	76	https://www.quikrjobs.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
114	98	https://www.makemytrip.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
115	98	https://trips.makemytrip.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
116	92	https://www.skyscanner.net	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
117	92	https://www.skyscanner.com	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
118	117	https://www.grab.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
119	117	https://driver.grab.com	subdomain	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
120	74	https://www.gumtree.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
121	74	https://www.gumtree.com.au	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
122	75	https://www.olx.com	root	https	t	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
123	75	https://www.olx.in	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
124	75	https://www.olx.com.br	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
125	75	https://www.olx.pl	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
126	75	https://www.olx.pk	root	https	f	t	2026-07-15 09:46:31.905889+05:30	\N	2026-07-15 09:46:31.905889+05:30
\.


--
-- Data for Name: trust_signal; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.trust_signal (id, marketplace_id, signal_type, issuer, valid_until, source_url, created_at) FROM stdin;
\.


--
-- Data for Name: url_alias; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.url_alias (id, alias_url, canonical_url_id, alias_type, created_at) FROM stdin;
\.


--
-- Data for Name: whitelist_audit_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.whitelist_audit_log (id, action, table_name, record_id, changed_by, note, occurred_at) FROM stdin;
\.


--
-- Name: marketplace_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.marketplace_category_id_seq', 17, true);


--
-- Name: marketplace_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.marketplace_id_seq', 179, true);


--
-- Name: marketplace_url_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.marketplace_url_id_seq', 126, true);


--
-- Name: trust_signal_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.trust_signal_id_seq', 1, false);


--
-- Name: url_alias_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.url_alias_id_seq', 1, false);


--
-- Name: whitelist_audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.whitelist_audit_log_id_seq', 1, false);


--
-- Name: marketplace_category marketplace_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace_category
    ADD CONSTRAINT marketplace_category_pkey PRIMARY KEY (id);


--
-- Name: marketplace_category marketplace_category_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace_category
    ADD CONSTRAINT marketplace_category_slug_key UNIQUE (slug);


--
-- Name: marketplace marketplace_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace
    ADD CONSTRAINT marketplace_pkey PRIMARY KEY (id);


--
-- Name: marketplace_url marketplace_url_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace_url
    ADD CONSTRAINT marketplace_url_pkey PRIMARY KEY (id);


--
-- Name: marketplace_url marketplace_url_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace_url
    ADD CONSTRAINT marketplace_url_url_key UNIQUE (url);


--
-- Name: trust_signal trust_signal_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trust_signal
    ADD CONSTRAINT trust_signal_pkey PRIMARY KEY (id);


--
-- Name: url_alias url_alias_alias_url_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.url_alias
    ADD CONSTRAINT url_alias_alias_url_key UNIQUE (alias_url);


--
-- Name: url_alias url_alias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.url_alias
    ADD CONSTRAINT url_alias_pkey PRIMARY KEY (id);


--
-- Name: whitelist_audit_log whitelist_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.whitelist_audit_log
    ADD CONSTRAINT whitelist_audit_log_pkey PRIMARY KEY (id);


--
-- Name: idx_marketplace_url_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marketplace_url_trgm ON public.marketplace_url USING gin (url public.gin_trgm_ops);


--
-- Name: idx_marketplace_url_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marketplace_url_type ON public.marketplace_url USING btree (url_type);


--
-- Name: idx_marketplace_url_verified; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marketplace_url_verified ON public.marketplace_url USING btree (is_verified);


--
-- Name: marketplace set_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.marketplace FOR EACH ROW EXECUTE FUNCTION public.trg_set_updated_at();


--
-- Name: marketplace marketplace_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace
    ADD CONSTRAINT marketplace_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.marketplace_category(id);


--
-- Name: marketplace_url marketplace_url_marketplace_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marketplace_url
    ADD CONSTRAINT marketplace_url_marketplace_id_fkey FOREIGN KEY (marketplace_id) REFERENCES public.marketplace(id) ON DELETE CASCADE;


--
-- Name: trust_signal trust_signal_marketplace_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.trust_signal
    ADD CONSTRAINT trust_signal_marketplace_id_fkey FOREIGN KEY (marketplace_id) REFERENCES public.marketplace(id) ON DELETE CASCADE;


--
-- Name: url_alias url_alias_canonical_url_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.url_alias
    ADD CONSTRAINT url_alias_canonical_url_id_fkey FOREIGN KEY (canonical_url_id) REFERENCES public.marketplace_url(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 9CkakTxGTzZKfazMzhooEHAHhqkVio7eZPfsceqt6S2Y2Hb5KMw3ElGDgmQ1B1U

