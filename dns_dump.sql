--
-- PostgreSQL database dump
--

\restrict ZHPG7PZURS9YfVls2aFJV1bkfqBJddwXRjieY4fIuuNMpnrz0LZ7983iFMv3wGG

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
-- Name: is_domain_blocked(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_domain_blocked(p_domain text) RETURNS TABLE(is_blocked boolean, category text, severity smallint, subdomain_block boolean, source text)
    LANGUAGE sql STABLE
    AS $$
    SELECT
        TRUE,
        dc.label::TEXT,
        de.severity,
        de.subdomain_block,
        de.source::TEXT
    FROM dns_entry de
    JOIN dns_category dc ON dc.id = de.category_id
    WHERE de.domain = p_domain
      AND de.is_active = TRUE
    LIMIT 1;
$$;


ALTER FUNCTION public.is_domain_blocked(p_domain text) OWNER TO postgres;

--
-- Name: is_domain_blocked_wildcard(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_domain_blocked_wildcard(p_domain text) RETURNS TABLE(is_blocked boolean, matched_rule text, category text, severity smallint)
    LANGUAGE plpgsql STABLE
    AS $$
DECLARE
    v_parts TEXT[];
    v_candidate TEXT;
    v_rec RECORD;
    i INT;
BEGIN
    v_parts := string_to_array(p_domain, '.');
    FOR i IN 1 .. array_length(v_parts, 1) LOOP
        v_candidate := array_to_string(v_parts[i:array_length(v_parts,1)], '.');
        SELECT de.domain, dc.label, de.severity
          INTO v_rec
          FROM dns_entry de
          JOIN dns_category dc ON dc.id = de.category_id
         WHERE de.domain = v_candidate
           AND de.is_active = TRUE
           AND (de.subdomain_block = TRUE OR v_candidate = p_domain)
         LIMIT 1;
        IF FOUND THEN
            RETURN QUERY SELECT TRUE, v_rec.domain::TEXT, v_rec.label::TEXT, v_rec.severity;
            RETURN;
        END IF;
    END LOOP;
    RETURN QUERY SELECT FALSE, NULL::TEXT, NULL::TEXT, NULL::SMALLINT;
END;
$$;


ALTER FUNCTION public.is_domain_blocked_wildcard(p_domain text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: blocklist_feed; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.blocklist_feed (
    id integer NOT NULL,
    name character varying(128) NOT NULL,
    url text,
    format character varying(32) DEFAULT 'hosts'::character varying,
    last_fetched timestamp with time zone,
    entry_count integer,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT blocklist_feed_format_check CHECK (((format)::text = ANY ((ARRAY['hosts'::character varying, 'abp'::character varying, 'easylist'::character varying, 'dnsmasq'::character varying, 'plain'::character varying, 'json'::character varying])::text[])))
);


ALTER TABLE public.blocklist_feed OWNER TO postgres;

--
-- Name: blocklist_feed_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.blocklist_feed_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.blocklist_feed_id_seq OWNER TO postgres;

--
-- Name: blocklist_feed_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.blocklist_feed_id_seq OWNED BY public.blocklist_feed.id;


--
-- Name: dns_category; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dns_category (
    id integer NOT NULL,
    slug character varying(64) NOT NULL,
    label character varying(128) NOT NULL,
    description text,
    severity smallint DEFAULT 2 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dns_category_severity_check CHECK (((severity >= 1) AND (severity <= 5)))
);


ALTER TABLE public.dns_category OWNER TO postgres;

--
-- Name: dns_category_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dns_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dns_category_id_seq OWNER TO postgres;

--
-- Name: dns_category_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dns_category_id_seq OWNED BY public.dns_category.id;


--
-- Name: dns_entry; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dns_entry (
    id bigint NOT NULL,
    domain character varying(253) NOT NULL,
    subdomain_block boolean DEFAULT true NOT NULL,
    category_id integer NOT NULL,
    severity smallint DEFAULT 2 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    source character varying(128),
    first_seen date,
    last_seen date,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dns_entry_severity_check CHECK (((severity >= 1) AND (severity <= 5)))
);


ALTER TABLE public.dns_entry OWNER TO postgres;

--
-- Name: dns_entry_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dns_entry_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dns_entry_id_seq OWNER TO postgres;

--
-- Name: dns_entry_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dns_entry_id_seq OWNED BY public.dns_entry.id;


--
-- Name: dns_exception; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dns_exception (
    id bigint NOT NULL,
    domain character varying(253) NOT NULL,
    reason text,
    added_by character varying(128),
    valid_until date,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.dns_exception OWNER TO postgres;

--
-- Name: dns_exception_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dns_exception_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dns_exception_id_seq OWNER TO postgres;

--
-- Name: dns_exception_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dns_exception_id_seq OWNED BY public.dns_exception.id;


--
-- Name: dns_query_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dns_query_log (
    id bigint NOT NULL,
    queried_at timestamp with time zone DEFAULT now() NOT NULL,
    client_ip inet,
    domain character varying(253) NOT NULL,
    was_blocked boolean DEFAULT false NOT NULL,
    entry_id bigint,
    resolver_ms smallint
);


ALTER TABLE public.dns_query_log OWNER TO postgres;

--
-- Name: dns_query_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dns_query_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dns_query_log_id_seq OWNER TO postgres;

--
-- Name: dns_query_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dns_query_log_id_seq OWNED BY public.dns_query_log.id;


--
-- Name: ip_blocklist; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ip_blocklist (
    id bigint NOT NULL,
    ip_cidr inet NOT NULL,
    category_id integer NOT NULL,
    asn integer,
    asn_org character varying(256),
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.ip_blocklist OWNER TO postgres;

--
-- Name: ip_blocklist_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ip_blocklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ip_blocklist_id_seq OWNER TO postgres;

--
-- Name: ip_blocklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ip_blocklist_id_seq OWNED BY public.ip_blocklist.id;


--
-- Name: v_blocklist_full; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_blocklist_full AS
 SELECT de.domain,
    de.subdomain_block,
    dc.slug AS category_slug,
    dc.label AS category,
    dc.severity AS category_severity,
    de.severity AS entry_severity,
    de.source,
    de.is_active,
    de.notes,
    de.first_seen,
    de.created_at
   FROM (public.dns_entry de
     JOIN public.dns_category dc ON ((dc.id = de.category_id)))
  ORDER BY de.severity DESC, dc.slug, de.domain;


ALTER VIEW public.v_blocklist_full OWNER TO postgres;

--
-- Name: v_high_severity; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_high_severity AS
 SELECT domain,
    category_id,
    severity,
    source,
    notes
   FROM public.dns_entry
  WHERE ((severity >= 4) AND (is_active = true))
  ORDER BY severity DESC, domain;


ALTER VIEW public.v_high_severity OWNER TO postgres;

--
-- Name: v_stats_by_category; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_stats_by_category AS
 SELECT dc.label,
    dc.severity AS cat_severity,
    count(de.id) AS total_entries,
    count(de.id) FILTER (WHERE de.is_active) AS active_entries
   FROM (public.dns_category dc
     LEFT JOIN public.dns_entry de ON ((de.category_id = dc.id)))
  GROUP BY dc.id, dc.label, dc.severity
  ORDER BY (count(de.id)) DESC;


ALTER VIEW public.v_stats_by_category OWNER TO postgres;

--
-- Name: blocklist_feed id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocklist_feed ALTER COLUMN id SET DEFAULT nextval('public.blocklist_feed_id_seq'::regclass);


--
-- Name: dns_category id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_category ALTER COLUMN id SET DEFAULT nextval('public.dns_category_id_seq'::regclass);


--
-- Name: dns_entry id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_entry ALTER COLUMN id SET DEFAULT nextval('public.dns_entry_id_seq'::regclass);


--
-- Name: dns_exception id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_exception ALTER COLUMN id SET DEFAULT nextval('public.dns_exception_id_seq'::regclass);


--
-- Name: dns_query_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_query_log ALTER COLUMN id SET DEFAULT nextval('public.dns_query_log_id_seq'::regclass);


--
-- Name: ip_blocklist id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ip_blocklist ALTER COLUMN id SET DEFAULT nextval('public.ip_blocklist_id_seq'::regclass);


--
-- Data for Name: blocklist_feed; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.blocklist_feed (id, name, url, format, last_fetched, entry_count, is_active, notes, created_at) FROM stdin;
1	EasyList	https://easylist.to/easylist/easylist.txt	easylist	\N	\N	t	Primary ad filter list	2026-07-15 09:55:12.624605+05:30
2	EasyPrivacy	https://easylist.to/easylist/easyprivacy.txt	easylist	\N	\N	t	Tracking filter list	2026-07-15 09:55:12.624605+05:30
3	AdGuard DNS	https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt	abp	\N	\N	t	AdGuard DNS default	2026-07-15 09:55:12.624605+05:30
4	AdGuard Base	https://filters.adtidy.org/extension/chromium/filters/2.txt	abp	\N	\N	t	AdGuard base filter	2026-07-15 09:55:12.624605+05:30
5	Steven Black Hosts	https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts	hosts	\N	\N	t	Amalgamated hosts list	2026-07-15 09:55:12.624605+05:30
6	Dan Pollock Hosts	https://someonewhocares.org/hosts/hosts	hosts	\N	\N	t	Classic hand-curated list	2026-07-15 09:55:12.624605+05:30
7	OISD Basic	https://dbl.oisd.nl/basic	abp	\N	\N	t	OISD basic blocklist	2026-07-15 09:55:12.624605+05:30
8	OISD Full	https://dbl.oisd.nl	abp	\N	\N	t	OISD full blocklist	2026-07-15 09:55:12.624605+05:30
9	Disconnect.me	https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt	plain	\N	\N	t	Disconnect tracking list	2026-07-15 09:55:12.624605+05:30
10	Peter Lowes Ad List	https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts	hosts	\N	\N	t	Yoyo.org ad servers	2026-07-15 09:55:12.624605+05:30
11	URLhaus	https://urlhaus.abuse.ch/downloads/hostfile	hosts	\N	\N	t	Abuse.ch malware URLs	2026-07-15 09:55:12.624605+05:30
12	Malware Domain List	https://www.malwaredomainlist.com/hostslist/hosts.txt	hosts	\N	\N	t	MDL classic list	2026-07-15 09:55:12.624605+05:30
13	Phishtank	https://data.phishtank.com/data/online-valid.csv	json	\N	\N	t	Verified phishing URLs	2026-07-15 09:55:12.624605+05:30
14	OpenPhish	https://openphish.com/feed.txt	plain	\N	\N	t	OpenPhish community feed	2026-07-15 09:55:12.624605+05:30
15	NoCoin	https://raw.githubusercontent.com/nicehash/NoCoin-adblock-list/master/adblock.txt	abp	\N	\N	t	Crypto-miner blocklist	2026-07-15 09:55:12.624605+05:30
16	CoinBlockerLists	https://zerodot1.gitlab.io/CoinBlockerLists/hosts_browser	hosts	\N	\N	t	Browser-based miners	2026-07-15 09:55:12.624605+05:30
17	Goodbye Ads	https://raw.githubusercontent.com/jerryn70/GoodbyeAds/master/Hosts/GoodbyeAds.txt	hosts	\N	\N	t	Mobile ad blocklist	2026-07-15 09:55:12.624605+05:30
18	HaGeZi Multi PRO	https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/pro.txt	hosts	\N	\N	t	HaGeZi curated list	2026-07-15 09:55:12.624605+05:30
19	1Hosts Lite	https://o0.pages.dev/Lite/hosts.txt	hosts	\N	\N	t	1Hosts lite	2026-07-15 09:55:12.624605+05:30
20	Spam404	https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt	plain	\N	\N	t	Scam/fraud domains	2026-07-15 09:55:12.624605+05:30
\.


--
-- Data for Name: dns_category; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dns_category (id, slug, label, description, severity, created_at) FROM stdin;
1	ad_network	Ad Network	Core advertisement serving domains	2	2026-07-15 09:55:12.583583+05:30
2	tracking	Tracking / Analytics	User behaviour tracking and analytics beacons	2	2026-07-15 09:55:12.583583+05:30
3	telemetry	Telemetry / Diagnostics	OS and app telemetry collection endpoints	2	2026-07-15 09:55:12.583583+05:30
4	social_tracker	Social Media Tracker	Third-party social pixels and widgets	2	2026-07-15 09:55:12.583583+05:30
5	retargeting	Retargeting / Remarketing	Retargeting pixels and DSP partners	2	2026-07-15 09:55:12.583583+05:30
6	data_broker	Data Broker	Data aggregation and resale services	3	2026-07-15 09:55:12.583583+05:30
7	malware	Malware / Exploit	Known malware C2 and exploit kit domains	5	2026-07-15 09:55:12.583583+05:30
8	phishing	Phishing / Fraud	Credential-stealing and fraud sites	5	2026-07-15 09:55:12.583583+05:30
9	cryptominer	Cryptominer	Browser-based and hidden coin-mining scripts	4	2026-07-15 09:55:12.583583+05:30
10	ransomware	Ransomware C2	Ransomware command-and-control servers	5	2026-07-15 09:55:12.583583+05:30
11	pup	PUP / Adware	Potentially unwanted programs and bundled adware	3	2026-07-15 09:55:12.583583+05:30
12	pop_under	Pop-under / Pop-up	Intrusive interstitial and pop ad networks	2	2026-07-15 09:55:12.583583+05:30
13	affiliate	Affiliate / Redirect	Affiliate click-tracking redirectors	1	2026-07-15 09:55:12.583583+05:30
14	click_fraud	Click Fraud	Fraudulent click-injection and IVT networks	4	2026-07-15 09:55:12.583583+05:30
15	fingerprinting	Browser Fingerprinting	Canvas/WebGL fingerprinting scripts	3	2026-07-15 09:55:12.583583+05:30
16	spyware	Spyware / Stalkerware	Covert surveillance and location tracking	5	2026-07-15 09:55:12.583583+05:30
17	adult	Adult / NSFW	Adult content advertising networks	2	2026-07-15 09:55:12.583583+05:30
18	fake_news	Fake News / Clickbait	Outbrain-style clickbait and misinformation	2	2026-07-15 09:55:12.583583+05:30
19	coin_hive	CoinHive Legacy	Defunct Coinhive and clones (still seen in wild)	4	2026-07-15 09:55:12.583583+05:30
20	cdn_abuse	CDN Abuse	Legitimate CDNs abused for malware delivery	3	2026-07-15 09:55:12.583583+05:30
\.


--
-- Data for Name: dns_entry; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dns_entry (id, domain, subdomain_block, category_id, severity, is_active, source, first_seen, last_seen, notes, created_at) FROM stdin;
1	d.adroll.com	t	5	2	t	EasyList	\N	\N	AdRoll pixel	2026-07-15 09:55:12.635224+05:30
2	google-analytics.com	t	2	2	t	EasyPrivacy	\N	\N	Google Analytics	2026-07-15 09:55:12.639609+05:30
3	ssl.google-analytics.com	t	2	2	t	EasyPrivacy	\N	\N	GA SSL endpoint	2026-07-15 09:55:12.639609+05:30
4	www.google-analytics.com	t	2	2	t	EasyPrivacy	\N	\N	GA main endpoint	2026-07-15 09:55:12.639609+05:30
5	analytics.google.com	t	2	2	t	EasyPrivacy	\N	\N	GA4	2026-07-15 09:55:12.639609+05:30
6	www.googletagmanager.com	t	2	2	t	EasyPrivacy	\N	\N	Google Tag Manager	2026-07-15 09:55:12.639609+05:30
7	googletagservices.com	t	2	2	t	EasyPrivacy	\N	\N	Google Tag Services	2026-07-15 09:55:12.639609+05:30
8	segment.com	t	2	2	t	EasyPrivacy	\N	\N	Segment CDP	2026-07-15 09:55:12.639609+05:30
9	api.segment.io	t	2	2	t	EasyPrivacy	\N	\N	Segment API	2026-07-15 09:55:12.639609+05:30
10	cdn.segment.com	t	2	2	t	EasyPrivacy	\N	\N	Segment CDN	2026-07-15 09:55:12.639609+05:30
11	amplitude.com	t	2	2	t	EasyPrivacy	\N	\N	Amplitude analytics	2026-07-15 09:55:12.639609+05:30
12	api.amplitude.com	t	2	2	t	EasyPrivacy	\N	\N	Amplitude API	2026-07-15 09:55:12.639609+05:30
13	mixpanel.com	t	2	2	t	EasyPrivacy	\N	\N	Mixpanel analytics	2026-07-15 09:55:12.639609+05:30
14	api.mixpanel.com	t	2	2	t	EasyPrivacy	\N	\N	Mixpanel API	2026-07-15 09:55:12.639609+05:30
15	heapanalytics.com	t	2	2	t	EasyPrivacy	\N	\N	Heap analytics	2026-07-15 09:55:12.639609+05:30
16	hotjar.com	t	2	2	t	EasyPrivacy	\N	\N	Hotjar heatmaps	2026-07-15 09:55:12.639609+05:30
17	script.hotjar.com	t	2	2	t	EasyPrivacy	\N	\N	Hotjar script host	2026-07-15 09:55:12.639609+05:30
18	static.hotjar.com	t	2	2	t	EasyPrivacy	\N	\N	Hotjar static	2026-07-15 09:55:12.639609+05:30
19	fullstory.com	t	2	2	t	EasyPrivacy	\N	\N	FullStory session recording	2026-07-15 09:55:12.639609+05:30
20	rs.fullstory.com	t	2	2	t	EasyPrivacy	\N	\N	FullStory relay	2026-07-15 09:55:12.639609+05:30
21	mouseflow.com	t	2	2	t	EasyPrivacy	\N	\N	Mouseflow session replay	2026-07-15 09:55:12.639609+05:30
22	clarity.ms	t	2	2	t	EasyPrivacy	\N	\N	Microsoft Clarity	2026-07-15 09:55:12.639609+05:30
23	quantcast.com	t	2	3	t	EasyPrivacy	\N	\N	Quantcast audience measurement	2026-07-15 09:55:12.639609+05:30
24	quantserve.com	t	2	3	t	EasyPrivacy	\N	\N	Quantcast pixel server	2026-07-15 09:55:12.639609+05:30
25	imrworldwide.com	t	2	2	t	EasyPrivacy	\N	\N	Nielsen NetRatings	2026-07-15 09:55:12.639609+05:30
26	scorecardresearch.com	t	2	2	t	EasyPrivacy	\N	\N	comScore ScorecardResearch	2026-07-15 09:55:12.639609+05:30
27	beacon.scorecardresearch.com	t	2	2	t	EasyPrivacy	\N	\N	comScore beacon	2026-07-15 09:55:12.639609+05:30
28	omtrdc.net	t	2	2	t	EasyPrivacy	\N	\N	Adobe Analytics (Omniture)	2026-07-15 09:55:12.639609+05:30
29	adobedtm.com	t	2	2	t	EasyPrivacy	\N	\N	Adobe DTM tag manager	2026-07-15 09:55:12.639609+05:30
30	demdex.net	t	2	3	t	EasyPrivacy	\N	\N	Adobe Audience Manager	2026-07-15 09:55:12.639609+05:30
31	chartbeat.com	t	2	2	t	EasyPrivacy	\N	\N	Chartbeat real-time analytics	2026-07-15 09:55:12.639609+05:30
32	static.chartbeat.com	t	2	2	t	EasyPrivacy	\N	\N	Chartbeat static	2026-07-15 09:55:12.639609+05:30
33	nr-data.net	t	3	2	t	EasyPrivacy	\N	\N	New Relic browser agent	2026-07-15 09:55:12.639609+05:30
34	browser-intake-datadoghq.com	t	3	2	t	manual	\N	\N	Datadog browser RUM	2026-07-15 09:55:12.639609+05:30
35	sentry.io	t	3	1	t	manual	\N	\N	Sentry error tracking (low-privacy risk but sends data)	2026-07-15 09:55:12.639609+05:30
36	lr-ingest.io	t	2	2	t	manual	\N	\N	LogRocket session replay	2026-07-15 09:55:12.639609+05:30
37	snowplow.io	t	2	2	t	manual	\N	\N	Snowplow behavioral data	2026-07-15 09:55:12.639609+05:30
38	mparticle.com	t	2	2	t	manual	\N	\N	mParticle CDP	2026-07-15 09:55:12.639609+05:30
39	tiqcdn.com	t	2	2	t	EasyPrivacy	\N	\N	Tealium iQ tag	2026-07-15 09:55:12.639609+05:30
40	collect.tealiumiq.com	t	2	2	t	EasyPrivacy	\N	\N	Tealium event collect	2026-07-15 09:55:12.639609+05:30
41	klaviyo.com	t	2	2	t	manual	\N	\N	Klaviyo email tracking	2026-07-15 09:55:12.639609+05:30
42	braze.com	t	2	2	t	manual	\N	\N	Braze in-app tracking	2026-07-15 09:55:12.639609+05:30
43	onesignal.com	t	2	1	t	manual	\N	\N	OneSignal push tracking	2026-07-15 09:55:12.639609+05:30
44	telemetry.microsoft.com	t	3	2	t	Steven Black	\N	\N	Windows telemetry	2026-07-15 09:55:12.643026+05:30
45	vortex.data.microsoft.com	t	3	2	t	Steven Black	\N	\N	Windows diagnostic data	2026-07-15 09:55:12.643026+05:30
46	watson.telemetry.microsoft.com	t	3	2	t	Steven Black	\N	\N	Watson crash reporting	2026-07-15 09:55:12.643026+05:30
47	settings-win.data.microsoft.com	t	3	2	t	Steven Black	\N	\N	Windows settings telemetry	2026-07-15 09:55:12.643026+05:30
48	sqm.telemetry.microsoft.com	t	3	2	t	Steven Black	\N	\N	SQM telemetry	2026-07-15 09:55:12.643026+05:30
49	oca.telemetry.microsoft.com	t	3	2	t	Steven Black	\N	\N	OCA telemetry	2026-07-15 09:55:12.643026+05:30
50	teredo.ipv6.microsoft.com	t	3	1	t	manual	\N	\N	Teredo mapping	2026-07-15 09:55:12.643026+05:30
51	stats.adobe.com	t	3	2	t	EasyPrivacy	\N	\N	Adobe app telemetry	2026-07-15 09:55:12.643026+05:30
52	metrics.apple.com	t	3	2	t	manual	\N	\N	Apple metrics	2026-07-15 09:55:12.643026+05:30
53	securemetrics.apple.com	t	3	2	t	manual	\N	\N	Apple secure metrics	2026-07-15 09:55:12.643026+05:30
54	api.apple-cloudkit.com	t	3	1	t	manual	\N	\N	Apple CloudKit sync	2026-07-15 09:55:12.643026+05:30
55	events.data.linkedin.com	t	3	2	t	EasyPrivacy	\N	\N	LinkedIn data events	2026-07-15 09:55:12.643026+05:30
56	analytics.tiktok.com	t	3	3	t	AdGuard DNS	\N	\N	TikTok analytics (privacy concern)	2026-07-15 09:55:12.643026+05:30
57	log.byteoversea.com	t	3	3	t	AdGuard DNS	\N	\N	TikTok/ByteDance log server	2026-07-15 09:55:12.643026+05:30
58	msa.lg.com	t	3	2	t	OISD Full	\N	\N	LG smart TV telemetry	2026-07-15 09:55:12.643026+05:30
59	ngfts.lge.com	t	3	2	t	OISD Full	\N	\N	LG firmware telemetry	2026-07-15 09:55:12.643026+05:30
60	samsung.samsungrs.com	t	3	2	t	OISD Full	\N	\N	Samsung TV telemetry	2026-07-15 09:55:12.643026+05:30
61	samsungacr.com	t	3	3	t	OISD Full	\N	\N	Samsung ACR (content recognition)	2026-07-15 09:55:12.643026+05:30
62	vizio.com	t	3	3	t	OISD Full	\N	\N	Vizio smart TV ACR/telemetry	2026-07-15 09:55:12.643026+05:30
63	rokuads.com	t	1	2	t	OISD Full	\N	\N	Roku advertising	2026-07-15 09:55:12.643026+05:30
64	scribe.logs.roku.com	t	3	2	t	OISD Full	\N	\N	Roku log endpoint	2026-07-15 09:55:12.643026+05:30
65	platform.twitter.com	t	4	2	t	EasyPrivacy	\N	\N	Twitter widget / pixel	2026-07-15 09:55:12.646399+05:30
66	ads.twitter.com	t	1	2	t	EasyList	\N	\N	Twitter Ads	2026-07-15 09:55:12.646399+05:30
67	analytics.twitter.com	t	2	2	t	EasyPrivacy	\N	\N	Twitter analytics	2026-07-15 09:55:12.646399+05:30
68	static.ads-twitter.com	t	1	2	t	EasyList	\N	\N	Twitter ads static	2026-07-15 09:55:12.646399+05:30
69	ads-api.twitter.com	t	1	2	t	EasyList	\N	\N	Twitter ads API	2026-07-15 09:55:12.646399+05:30
70	pixel.twitter.com	t	2	2	t	EasyPrivacy	\N	\N	Twitter pixel	2026-07-15 09:55:12.646399+05:30
71	linkedin.com	t	4	1	t	manual	\N	\N	LinkedIn (social tracking when embedded)	2026-07-15 09:55:12.646399+05:30
72	px.ads.linkedin.com	t	1	2	t	EasyList	\N	\N	LinkedIn ad pixel	2026-07-15 09:55:12.646399+05:30
73	snap.licdn.com	t	2	2	t	EasyPrivacy	\N	\N	LinkedIn Insights tag	2026-07-15 09:55:12.646399+05:30
74	bat.bing.com	t	2	2	t	EasyPrivacy	\N	\N	Bing UET tracking	2026-07-15 09:55:12.646399+05:30
75	ads.pinterest.com	t	1	2	t	EasyList	\N	\N	Pinterest Ads	2026-07-15 09:55:12.646399+05:30
76	ct.pinterest.com	t	2	2	t	EasyPrivacy	\N	\N	Pinterest tag	2026-07-15 09:55:12.646399+05:30
77	sc-static.net	t	1	2	t	EasyList	\N	\N	Snapchat Ads static	2026-07-15 09:55:12.646399+05:30
78	tr.snapchat.com	t	2	2	t	EasyPrivacy	\N	\N	Snapchat pixel	2026-07-15 09:55:12.646399+05:30
79	ads.tiktok.com	t	1	3	t	AdGuard DNS	\N	\N	TikTok Ads Manager	2026-07-15 09:55:12.646399+05:30
80	fingerprintjs.com	t	15	3	t	manual	\N	\N	FingerprintJS device ID	2026-07-15 09:55:12.64903+05:30
81	api.fpjs.io	t	15	3	t	manual	\N	\N	FingerprintJS API	2026-07-15 09:55:12.64903+05:30
82	cdn.deviceatlas.com	t	15	3	t	manual	\N	\N	DeviceAtlas fingerprint	2026-07-15 09:55:12.64903+05:30
83	iovation.com	t	15	3	t	manual	\N	\N	iovation device risk	2026-07-15 09:55:12.64903+05:30
84	threatmetrix.com	t	15	3	t	manual	\N	\N	ThreatMetrix device ID	2026-07-15 09:55:12.64903+05:30
85	kaptcha.com	t	15	2	t	manual	\N	\N	Kochava fingerprint	2026-07-15 09:55:12.64903+05:30
86	kochava.com	t	2	3	t	AdGuard DNS	\N	\N	Kochava mobile MMP	2026-07-15 09:55:12.64903+05:30
87	coinhive.com	t	19	4	t	NoCoin	\N	\N	Original CoinHive miner (defunct)	2026-07-15 09:55:12.650148+05:30
88	cnhv.co	t	19	4	t	NoCoin	\N	\N	CoinHive short domain	2026-07-15 09:55:12.650148+05:30
89	coin-hive.com	t	19	4	t	NoCoin	\N	\N	CoinHive alt domain	2026-07-15 09:55:12.650148+05:30
90	jsecoin.com	t	9	4	t	NoCoin	\N	\N	JSECoin browser miner	2026-07-15 09:55:12.650148+05:30
91	monerominer.rocks	t	9	4	t	CoinBlockerLists	\N	\N	Monero miner	2026-07-15 09:55:12.650148+05:30
92	crypto-loot.com	t	9	4	t	NoCoin	\N	\N	CryptoLoot miner	2026-07-15 09:55:12.650148+05:30
93	2giga.link	t	9	4	t	NoCoin	\N	\N	Miner disguise domain	2026-07-15 09:55:12.650148+05:30
94	minero.pw	t	9	4	t	NoCoin	\N	\N	Minero.pw miner	2026-07-15 09:55:12.650148+05:30
95	webmine.pro	t	9	4	t	NoCoin	\N	\N	WebMine miner	2026-07-15 09:55:12.650148+05:30
96	ppoi.org	t	9	4	t	NoCoin	\N	\N	PPOI miner network	2026-07-15 09:55:12.650148+05:30
97	static.hashing.host	t	9	4	t	NoCoin	\N	\N	Hashing.host static CDN	2026-07-15 09:55:12.650148+05:30
98	hashing.win	t	9	4	t	NoCoin	\N	\N	Hashing.win miner	2026-07-15 09:55:12.650148+05:30
99	coinlab.biz	t	9	4	t	NoCoin	\N	\N	CoinLab miner	2026-07-15 09:55:12.650148+05:30
100	nbminer.com	t	9	4	t	CoinBlockerLists	\N	\N	NB Miner	2026-07-15 09:55:12.650148+05:30
101	webmr.ru	t	9	4	t	CoinBlockerLists	\N	\N	WebMR miner RU	2026-07-15 09:55:12.650148+05:30
102	minerpool.pw	t	9	4	t	CoinBlockerLists	\N	\N	MinerPool miner	2026-07-15 09:55:12.650148+05:30
103	malware-traffic-analysis.net	t	7	5	t	URLhaus	\N	\N	Known C2 test domain (reference)	2026-07-15 09:55:12.65179+05:30
104	fakebank-secure.com	t	8	5	t	Phishtank	\N	\N	Fake bank phishing	2026-07-15 09:55:12.65179+05:30
105	amazon-securelogin.net	t	8	5	t	Phishtank	\N	\N	Amazon phishing typosquat	2026-07-15 09:55:12.65179+05:30
106	paypal-verify.info	t	8	5	t	Phishtank	\N	\N	PayPal phishing	2026-07-15 09:55:12.65179+05:30
107	microsoft-support-alert.com	t	8	5	t	Phishtank	\N	\N	Tech support scam	2026-07-15 09:55:12.65179+05:30
108	apple-id-confirm.com	t	8	5	t	OpenPhish	\N	\N	Apple ID phishing	2026-07-15 09:55:12.65179+05:30
109	secure-netflixlogin.com	t	8	5	t	OpenPhish	\N	\N	Netflix phishing	2026-07-15 09:55:12.65179+05:30
110	fedex-track-parcel.com	t	8	5	t	Spam404	\N	\N	FedEx phishing	2026-07-15 09:55:12.65179+05:30
111	dhl-trackingservice.com	t	8	5	t	Spam404	\N	\N	DHL phishing	2026-07-15 09:55:12.65179+05:30
112	irs-taxrefund.com	t	8	5	t	Spam404	\N	\N	IRS tax refund scam	2026-07-15 09:55:12.65179+05:30
113	covid19-relief-fund.com	t	8	5	t	Spam404	\N	\N	COVID phishing	2026-07-15 09:55:12.65179+05:30
114	crypto-wallet-restore.com	t	8	5	t	OpenPhish	\N	\N	Crypto wallet drainer	2026-07-15 09:55:12.65179+05:30
115	nft-minting-promo.xyz	t	8	5	t	manual	\N	\N	NFT mint phishing	2026-07-15 09:55:12.65179+05:30
116	trojandownload.ru	t	7	5	t	URLhaus	\N	\N	Trojan dropper	2026-07-15 09:55:12.65179+05:30
117	exploit-kit.cc	t	7	5	t	URLhaus	\N	\N	Exploit kit host	2026-07-15 09:55:12.65179+05:30
118	emotet-c2.ru	t	7	5	t	URLhaus	\N	\N	Emotet C2	2026-07-15 09:55:12.65179+05:30
119	cobalt-strike-beacon.net	t	7	5	t	URLhaus	\N	\N	Cobalt Strike C2	2026-07-15 09:55:12.65179+05:30
120	lokibot-c2.cn	t	7	5	t	URLhaus	\N	\N	LokiBot C2	2026-07-15 09:55:12.65179+05:30
121	redline-stealer.pro	t	7	5	t	URLhaus	\N	\N	RedLine stealer C2	2026-07-15 09:55:12.65179+05:30
122	ransomware-decrypt.top	t	10	5	t	manual	\N	\N	Ransomware ransom page	2026-07-15 09:55:12.65179+05:30
123	lockbit-support.onion.ws	t	10	5	t	manual	\N	\N	LockBit clearnet mirror	2026-07-15 09:55:12.65179+05:30
124	conti-news.cc	t	10	5	t	manual	\N	\N	Conti ransomware (defunct)	2026-07-15 09:55:12.65179+05:30
125	superfish.com	t	11	3	t	manual	\N	\N	Superfish adware (Lenovo)	2026-07-15 09:55:12.653631+05:30
126	browsefox.com	t	11	3	t	manual	\N	\N	BrowseFox PUP	2026-07-15 09:55:12.653631+05:30
127	conduit.com	t	11	3	t	manual	\N	\N	Conduit toolbar	2026-07-15 09:55:12.653631+05:30
128	sweetim.com	t	11	3	t	manual	\N	\N	SweetIM toolbar	2026-07-15 09:55:12.653631+05:30
129	snapdo.com	t	11	3	t	manual	\N	\N	Snap.do browser hijacker	2026-07-15 09:55:12.653631+05:30
130	delta-search.com	t	11	3	t	manual	\N	\N	Delta Search hijacker	2026-07-15 09:55:12.653631+05:30
131	babylon.com	t	11	3	t	manual	\N	\N	Babylon toolbar	2026-07-15 09:55:12.653631+05:30
132	Ask.com	t	11	2	t	manual	\N	\N	Ask toolbar bundler	2026-07-15 09:55:12.653631+05:30
133	mywebsearch.com	t	11	3	t	manual	\N	\N	MyWebSearch toolbar	2026-07-15 09:55:12.653631+05:30
134	searchqu.com	t	11	3	t	manual	\N	\N	Searchqu hijacker	2026-07-15 09:55:12.653631+05:30
135	istart.webssearches.com	t	11	3	t	manual	\N	\N	WebSearches hijacker	2026-07-15 09:55:12.653631+05:30
136	dosearches.com	t	11	3	t	manual	\N	\N	DoSearches hijacker	2026-07-15 09:55:12.653631+05:30
137	popcash.net	t	12	2	t	EasyList	\N	\N	PopCash pop-under network	2026-07-15 09:55:12.655135+05:30
138	popads.net	t	12	2	t	EasyList	\N	\N	PopAds network	2026-07-15 09:55:12.655135+05:30
139	propellerads.com	t	12	2	t	EasyList	\N	\N	PropellerAds pop-under	2026-07-15 09:55:12.655135+05:30
140	advertiserhq.com	t	12	2	t	EasyList	\N	\N	AdvertiserHQ pop-under	2026-07-15 09:55:12.655135+05:30
141	clickadu.com	t	12	2	t	EasyList	\N	\N	ClickAdu network	2026-07-15 09:55:12.655135+05:30
142	adsterra.com	t	12	2	t	EasyList	\N	\N	Adsterra network	2026-07-15 09:55:12.655135+05:30
143	trafficfactory.biz	t	12	3	t	EasyList	\N	\N	TrafficFactory (adult traffic)	2026-07-15 09:55:12.655135+05:30
144	juicyads.com	t	17	2	t	EasyList	\N	\N	JuicyAds adult ad network	2026-07-15 09:55:12.655135+05:30
145	exoclick.com	t	17	2	t	EasyList	\N	\N	ExoClick adult network	2026-07-15 09:55:12.655135+05:30
146	trafficjunky.com	t	17	2	t	EasyList	\N	\N	TrafficJunky adult network	2026-07-15 09:55:12.655135+05:30
147	ero-advertising.com	t	17	2	t	EasyList	\N	\N	Ero-Advertising adult	2026-07-15 09:55:12.655135+05:30
148	adhitz.com	t	12	2	t	EasyList	\N	\N	AdHitz pop network	2026-07-15 09:55:12.655135+05:30
149	mgid.com	t	1	2	t	EasyList	\N	\N	MGID native ads	2026-07-15 09:55:12.655135+05:30
150	hilltopads.net	t	12	2	t	EasyList	\N	\N	HilltopAds network	2026-07-15 09:55:12.655135+05:30
151	revcontent.com	t	14	3	t	EasyList	\N	\N	RevContent (IVT concerns)	2026-07-15 09:55:12.656565+05:30
152	bouncexchange.com	t	2	2	t	EasyPrivacy	\N	\N	BounceX intent-based pop	2026-07-15 09:55:12.656565+05:30
153	justpremium.com	t	1	2	t	EasyList	\N	\N	JustPremium high-impact ads	2026-07-15 09:55:12.656565+05:30
154	fout.jp	t	14	3	t	AdGuard DNS	\N	\N	Japanese click fraud	2026-07-15 09:55:12.656565+05:30
155	eclick.vn	t	14	3	t	manual	\N	\N	Vietnamese click fraud	2026-07-15 09:55:12.656565+05:30
156	traffboost.net	t	14	4	t	manual	\N	\N	Click fraud botnet	2026-07-15 09:55:12.656565+05:30
157	ads2buy.com	t	14	4	t	manual	\N	\N	Click fraud domain	2026-07-15 09:55:12.656565+05:30
158	spokeo.com	t	6	3	t	manual	\N	\N	Spokeo people search	2026-07-15 09:55:12.657812+05:30
159	whitepages.com	t	6	3	t	manual	\N	\N	WhitePages data broker	2026-07-15 09:55:12.657812+05:30
160	intelius.com	t	6	3	t	manual	\N	\N	Intelius people finder	2026-07-15 09:55:12.657812+05:30
161	peoplefinders.com	t	6	3	t	manual	\N	\N	PeopleFinders broker	2026-07-15 09:55:12.657812+05:30
162	checkpeople.com	t	6	3	t	manual	\N	\N	CheckPeople broker	2026-07-15 09:55:12.657812+05:30
163	beenverified.com	t	6	3	t	manual	\N	\N	BeenVerified broker	2026-07-15 09:55:12.657812+05:30
164	instantcheckmate.com	t	6	3	t	manual	\N	\N	Instant Checkmate	2026-07-15 09:55:12.657812+05:30
165	truthfinder.com	t	6	3	t	manual	\N	\N	TruthFinder broker	2026-07-15 09:55:12.657812+05:30
166	experian.com	t	6	2	t	manual	\N	\N	Experian data (marketing arm)	2026-07-15 09:55:12.657812+05:30
167	datalogix.com	t	6	3	t	manual	\N	\N	Datalogix (Oracle Data Cloud)	2026-07-15 09:55:12.657812+05:30
168	nielsen.com	t	6	2	t	manual	\N	\N	Nielsen audience data	2026-07-15 09:55:12.657812+05:30
187	doubleclick.net	t	1	2	t	EasyList	\N	\N	Google/DoubleClick ad server	2026-07-15 10:02:58.28624+05:30
188	googlesyndication.com	t	1	2	t	EasyList	\N	\N	Google AdSense	2026-07-15 10:02:58.28624+05:30
189	googleadservices.com	t	1	2	t	EasyList	\N	\N	Google Ads click tracker	2026-07-15 10:02:58.28624+05:30
190	googleads.g.doubleclick.net	t	1	2	t	EasyList	\N	\N	DFP ad server	2026-07-15 10:02:58.28624+05:30
191	pagead2.googlesyndication.com	t	1	2	t	EasyList	\N	\N	AdSense script host	2026-07-15 10:02:58.28624+05:30
192	adservice.google.com	t	1	2	t	AdGuard DNS	\N	\N	Google ad service	2026-07-15 10:02:58.28624+05:30
193	amazon-adsystem.com	t	1	2	t	EasyList	\N	\N	Amazon DSP	2026-07-15 10:02:58.28624+05:30
194	adnxs.com	t	1	2	t	EasyList	\N	\N	AppNexus/Xandr ad exchange	2026-07-15 10:02:58.28624+05:30
195	rubiconproject.com	t	1	2	t	EasyList	\N	\N	Magnite/Rubicon SSP	2026-07-15 10:02:58.28624+05:30
196	pubmatic.com	t	1	2	t	EasyList	\N	\N	PubMatic SSP	2026-07-15 10:02:58.28624+05:30
197	criteo.com	t	5	2	t	EasyList	\N	\N	Criteo retargeting	2026-07-15 10:02:58.28624+05:30
198	taboola.com	t	18	2	t	EasyList	\N	\N	Taboola content recommendation	2026-07-15 10:02:58.28624+05:30
199	outbrain.com	t	18	2	t	EasyList	\N	\N	Outbrain content recommendation	2026-07-15 10:02:58.28624+05:30
200	adsrvr.org	t	1	2	t	AdGuard DNS	\N	\N	The Trade Desk DSP	2026-07-15 10:02:58.28624+05:30
201	openx.net	t	1	2	t	EasyList	\N	\N	OpenX ad exchange	2026-07-15 10:02:58.28624+05:30
202	casalemedia.com	t	1	2	t	EasyList	\N	\N	Index Exchange	2026-07-15 10:02:58.28624+05:30
203	an.facebook.com	t	1	2	t	EasyList	\N	\N	Facebook Audience Network	2026-07-15 10:02:58.28624+05:30
204	adroll.com	t	5	2	t	EasyList	\N	\N	AdRoll retargeting	2026-07-15 10:02:58.28624+05:30
205	an.yandex.ru	t	1	2	t	AdGuard DNS	\N	\N	Yandex Advertising Network	2026-07-15 10:02:58.28624+05:30
\.


--
-- Data for Name: dns_exception; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dns_exception (id, domain, reason, added_by, valid_until, created_at) FROM stdin;
\.


--
-- Data for Name: dns_query_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dns_query_log (id, queried_at, client_ip, domain, was_blocked, entry_id, resolver_ms) FROM stdin;
\.


--
-- Data for Name: ip_blocklist; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ip_blocklist (id, ip_cidr, category_id, asn, asn_org, is_active, notes, created_at) FROM stdin;
\.


--
-- Name: blocklist_feed_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.blocklist_feed_id_seq', 20, true);


--
-- Name: dns_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dns_category_id_seq', 20, true);


--
-- Name: dns_entry_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dns_entry_id_seq', 205, true);


--
-- Name: dns_exception_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dns_exception_id_seq', 1, false);


--
-- Name: dns_query_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dns_query_log_id_seq', 1, false);


--
-- Name: ip_blocklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ip_blocklist_id_seq', 1, false);


--
-- Name: blocklist_feed blocklist_feed_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocklist_feed
    ADD CONSTRAINT blocklist_feed_name_key UNIQUE (name);


--
-- Name: blocklist_feed blocklist_feed_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.blocklist_feed
    ADD CONSTRAINT blocklist_feed_pkey PRIMARY KEY (id);


--
-- Name: dns_category dns_category_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_category
    ADD CONSTRAINT dns_category_pkey PRIMARY KEY (id);


--
-- Name: dns_category dns_category_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_category
    ADD CONSTRAINT dns_category_slug_key UNIQUE (slug);


--
-- Name: dns_entry dns_entry_domain_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_entry
    ADD CONSTRAINT dns_entry_domain_key UNIQUE (domain);


--
-- Name: dns_entry dns_entry_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_entry
    ADD CONSTRAINT dns_entry_pkey PRIMARY KEY (id);


--
-- Name: dns_exception dns_exception_domain_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_exception
    ADD CONSTRAINT dns_exception_domain_key UNIQUE (domain);


--
-- Name: dns_exception dns_exception_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_exception
    ADD CONSTRAINT dns_exception_pkey PRIMARY KEY (id);


--
-- Name: dns_query_log dns_query_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_query_log
    ADD CONSTRAINT dns_query_log_pkey PRIMARY KEY (id);


--
-- Name: ip_blocklist ip_blocklist_ip_cidr_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ip_blocklist
    ADD CONSTRAINT ip_blocklist_ip_cidr_key UNIQUE (ip_cidr);


--
-- Name: ip_blocklist ip_blocklist_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ip_blocklist
    ADD CONSTRAINT ip_blocklist_pkey PRIMARY KEY (id);


--
-- Name: idx_dns_entry_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dns_entry_active ON public.dns_entry USING btree (is_active);


--
-- Name: idx_dns_entry_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dns_entry_category ON public.dns_entry USING btree (category_id);


--
-- Name: idx_dns_entry_domain_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dns_entry_domain_trgm ON public.dns_entry USING gin (domain public.gin_trgm_ops);


--
-- Name: idx_dns_entry_severity; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dns_entry_severity ON public.dns_entry USING btree (severity);


--
-- Name: idx_dns_entry_source; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dns_entry_source ON public.dns_entry USING btree (source);


--
-- Name: idx_dns_query_log_blocked; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dns_query_log_blocked ON public.dns_query_log USING btree (was_blocked);


--
-- Name: idx_dns_query_log_domain; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_dns_query_log_domain ON public.dns_query_log USING btree (domain);


--
-- Name: dns_entry dns_entry_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_entry
    ADD CONSTRAINT dns_entry_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.dns_category(id);


--
-- Name: dns_query_log dns_query_log_entry_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dns_query_log
    ADD CONSTRAINT dns_query_log_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.dns_entry(id);


--
-- Name: ip_blocklist ip_blocklist_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ip_blocklist
    ADD CONSTRAINT ip_blocklist_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.dns_category(id);


--
-- PostgreSQL database dump complete
--

\unrestrict ZHPG7PZURS9YfVls2aFJV1bkfqBJddwXRjieY4fIuuNMpnrz0LZ7983iFMv3wGG

