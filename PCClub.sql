--
-- PostgreSQL database dump
--

-- Dumped from database version 15.3
-- Dumped by pg_dump version 15.3

-- Started on 2025-05-21 08:53:53

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 232 (class 1255 OID 72374)
-- Name: add_client(text, text, text); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_client(IN p_full_name text, IN p_phone text, IN p_email text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO clients(full_name, phone, email)
    VALUES (p_full_name, p_phone, p_email);

    RAISE NOTICE 'Клиент "%" добавлен', p_full_name;
END;
$$;


ALTER PROCEDURE public.add_client(IN p_full_name text, IN p_phone text, IN p_email text) OWNER TO postgres;

--
-- TOC entry 231 (class 1255 OID 72373)
-- Name: add_new_game(text, text, integer); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.add_new_game(IN p_title text, IN p_genre text, IN p_release_year integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO games(title, genre, release_year)
    VALUES (p_title, p_genre, p_release_year);

    RAISE NOTICE 'Игра "%" добавлена', p_title;
END;
$$;


ALTER PROCEDURE public.add_new_game(IN p_title text, IN p_genre text, IN p_release_year integer) OWNER TO postgres;

--
-- TOC entry 234 (class 1255 OID 72386)
-- Name: check_session_duration(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_session_duration() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Проверка, что оба времени заданы
    IF NEW.start_time IS NOT NULL AND NEW.end_time IS NOT NULL THEN
        -- Проверка, что разница превышает 12 часов
        IF (NEW.end_time - NEW.start_time) > INTERVAL '12 hours' THEN
            RAISE EXCEPTION 'Сессия не может длиться более 12 часов';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_session_duration() OWNER TO postgres;

--
-- TOC entry 230 (class 1255 OID 72372)
-- Name: end_session(integer, timestamp without time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.end_session(IN p_session_id integer, IN p_end_time timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE sessions
    SET end_time = p_end_time
    WHERE session_id = p_session_id;

    RAISE NOTICE 'Сессия % завершена в %', p_session_id, p_end_time;
END;
$$;


ALTER PROCEDURE public.end_session(IN p_session_id integer, IN p_end_time timestamp without time zone) OWNER TO postgres;

--
-- TOC entry 235 (class 1255 OID 72388)
-- Name: get_client_session_count(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_client_session_count(p_client_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    session_count INT;
BEGIN
    SELECT COUNT(*) INTO session_count
    FROM sessions
    WHERE client_id = p_client_id;

    RETURN session_count;
END;
$$;


ALTER FUNCTION public.get_client_session_count(p_client_id integer) OWNER TO postgres;

--
-- TOC entry 236 (class 1255 OID 72389)
-- Name: get_games_played_by_client(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_games_played_by_client(p_client_id integer) RETURNS TABLE(game_title text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT g.title
    FROM games g
    JOIN sessions_games sg ON g.game_id = sg.game_id
    JOIN sessions s ON s.session_id = sg.session_id
    WHERE s.client_id = p_client_id;
END;
$$;


ALTER FUNCTION public.get_games_played_by_client(p_client_id integer) OWNER TO postgres;

--
-- TOC entry 237 (class 1255 OID 72390)
-- Name: is_session_active(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.is_session_active(p_session_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    result BOOLEAN;
BEGIN
    SELECT (end_time IS NULL) INTO result
    FROM sessions
    WHERE session_id = p_session_id;

    RETURN result;
END;
$$;


ALTER FUNCTION public.is_session_active(p_session_id integer) OWNER TO postgres;

--
-- TOC entry 233 (class 1255 OID 72385)
-- Name: log_session_end(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.log_session_end() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.end_time IS NOT NULL AND OLD.end_time IS DISTINCT FROM NEW.end_time THEN
        INSERT INTO session_logs(session_id, message)
        VALUES (NEW.session_id, 'Сессия завершена в ' || NEW.end_time);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.log_session_end() OWNER TO postgres;

--
-- TOC entry 229 (class 1255 OID 72371)
-- Name: start_session_with_game(integer, integer, integer, timestamp without time zone, timestamp without time zone); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.start_session_with_game(IN p_client_id integer, IN p_computer_id integer, IN p_game_id integer, IN p_start_time timestamp without time zone, IN p_end_time timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
DECLARE
    new_session_id INT;
BEGIN
    -- Вставляем новую сессию
    INSERT INTO sessions(client_id, computer_id, start_time, end_time)
    VALUES (p_client_id, p_computer_id, p_start_time, p_end_time)
    RETURNING session_id INTO new_session_id;

    -- Связываем с выбранной игрой
    INSERT INTO sessions_games(session_id, game_id)
    VALUES (new_session_id, p_game_id);

    RAISE NOTICE 'Сессия % создана с игрой %', new_session_id, p_game_id;
END;
$$;


ALTER PROCEDURE public.start_session_with_game(IN p_client_id integer, IN p_computer_id integer, IN p_game_id integer, IN p_start_time timestamp without time zone, IN p_end_time timestamp without time zone) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 226 (class 1259 OID 64136)
-- Name: admins; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.admins (
    id integer NOT NULL,
    username character varying(100) NOT NULL,
    password character varying(100) NOT NULL
);


ALTER TABLE public.admins OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 64135)
-- Name: admins_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.admins_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.admins_id_seq OWNER TO postgres;

--
-- TOC entry 3408 (class 0 OID 0)
-- Dependencies: 225
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.admins_id_seq OWNED BY public.admins.id;


--
-- TOC entry 215 (class 1259 OID 63807)
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    client_id integer NOT NULL,
    name character varying(100),
    phone character varying(30),
    registration_date timestamp with time zone DEFAULT now(),
    visible boolean DEFAULT true NOT NULL
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- TOC entry 223 (class 1259 OID 64026)
-- Name: client; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.client AS
 SELECT clients.client_id,
    clients.name
   FROM public.clients;


ALTER TABLE public.client OWNER TO postgres;

--
-- TOC entry 214 (class 1259 OID 63806)
-- Name: clients_client_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.clients_client_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.clients_client_id_seq OWNER TO postgres;

--
-- TOC entry 3409 (class 0 OID 0)
-- Dependencies: 214
-- Name: clients_client_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.clients_client_id_seq OWNED BY public.clients.client_id;


--
-- TOC entry 224 (class 1259 OID 64031)
-- Name: clientse; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.clientse AS
 SELECT clients.client_id,
    clients.name
   FROM public.clients
  WHERE (clients.visible IS TRUE);


ALTER TABLE public.clientse OWNER TO postgres;

--
-- TOC entry 217 (class 1259 OID 63815)
-- Name: computers ; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."computers " (
    computer_id integer NOT NULL,
    location character varying(75),
    specifications text
);


ALTER TABLE public."computers " OWNER TO postgres;

--
-- TOC entry 216 (class 1259 OID 63814)
-- Name: computers _computer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public."computers _computer_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public."computers _computer_id_seq" OWNER TO postgres;

--
-- TOC entry 3410 (class 0 OID 0)
-- Dependencies: 216
-- Name: computers _computer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public."computers _computer_id_seq" OWNED BY public."computers ".computer_id;


--
-- TOC entry 221 (class 1259 OID 63831)
-- Name: games; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.games (
    game_id integer NOT NULL,
    title character varying(100),
    genre character varying(75),
    publisher character varying(100),
    release_year integer
);


ALTER TABLE public.games OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 63830)
-- Name: games_game_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.games_game_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.games_game_id_seq OWNER TO postgres;

--
-- TOC entry 3411 (class 0 OID 0)
-- Dependencies: 220
-- Name: games_game_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.games_game_id_seq OWNED BY public.games.game_id;


--
-- TOC entry 222 (class 1259 OID 63837)
-- Name: session_games; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_games (
    session_id integer,
    game_id integer
);


ALTER TABLE public.session_games OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 72376)
-- Name: session_logs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.session_logs (
    log_id integer NOT NULL,
    session_id integer,
    log_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    message text
);


ALTER TABLE public.session_logs OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 72375)
-- Name: session_logs_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.session_logs_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.session_logs_log_id_seq OWNER TO postgres;

--
-- TOC entry 3412 (class 0 OID 0)
-- Dependencies: 227
-- Name: session_logs_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.session_logs_log_id_seq OWNED BY public.session_logs.log_id;


--
-- TOC entry 219 (class 1259 OID 63824)
-- Name: sessions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sessions (
    session_id integer NOT NULL,
    client_id integer,
    computer_id integer,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    total_cost numeric(8,2)
);


ALTER TABLE public.sessions OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 63823)
-- Name: sessions_session_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sessions_session_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.sessions_session_id_seq OWNER TO postgres;

--
-- TOC entry 3413 (class 0 OID 0)
-- Dependencies: 218
-- Name: sessions_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sessions_session_id_seq OWNED BY public.sessions.session_id;


--
-- TOC entry 3225 (class 2604 OID 64139)
-- Name: admins id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins ALTER COLUMN id SET DEFAULT nextval('public.admins_id_seq'::regclass);


--
-- TOC entry 3219 (class 2604 OID 63810)
-- Name: clients client_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients ALTER COLUMN client_id SET DEFAULT nextval('public.clients_client_id_seq'::regclass);


--
-- TOC entry 3222 (class 2604 OID 63818)
-- Name: computers  computer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."computers " ALTER COLUMN computer_id SET DEFAULT nextval('public."computers _computer_id_seq"'::regclass);


--
-- TOC entry 3224 (class 2604 OID 63834)
-- Name: games game_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.games ALTER COLUMN game_id SET DEFAULT nextval('public.games_game_id_seq'::regclass);


--
-- TOC entry 3226 (class 2604 OID 72379)
-- Name: session_logs log_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_logs ALTER COLUMN log_id SET DEFAULT nextval('public.session_logs_log_id_seq'::regclass);


--
-- TOC entry 3223 (class 2604 OID 63827)
-- Name: sessions session_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions ALTER COLUMN session_id SET DEFAULT nextval('public.sessions_session_id_seq'::regclass);


--
-- TOC entry 3400 (class 0 OID 64136)
-- Dependencies: 226
-- Data for Name: admins; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.admins (id, username, password) FROM stdin;
1	admin	0000
\.


--
-- TOC entry 3391 (class 0 OID 63807)
-- Dependencies: 215
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (client_id, name, phone, registration_date, visible) FROM stdin;
1	Ivan	1091	2025-03-21 00:00:00+03	t
2	Igor	2231	2025-03-21 00:00:00+03	t
3	Andrew	4213	2025-03-22 00:00:00+03	t
4	Denis	6313	2025-03-22 00:00:00+03	t
5	Aleksey	4544	2025-03-26 08:56:05.003589+03	t
\.


--
-- TOC entry 3393 (class 0 OID 63815)
-- Dependencies: 217
-- Data for Name: computers ; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public."computers " (computer_id, location, specifications) FROM stdin;
1	Zona "A" Pc - 1	RTX 3090 ,  RAM 32gb, SSD 2TB 
2	Zona "A" Pc-2	RTX 3090 ,  RAM 32gb, SSD 2TB 
3	Zona "B" Pc-3	RTX 3090 ,  RAM 32gb, SSD 2TB 
4	Zona "B" Pc-4	RTX 3090 ,  RAM 32gb, SSD 2TB 
5	Zona "VIP" Pc-5	RTX 5090 ,  RAM 64gb, SSD 2TB 
\.


--
-- TOC entry 3397 (class 0 OID 63831)
-- Dependencies: 221
-- Data for Name: games; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.games (game_id, title, genre, publisher, release_year) FROM stdin;
1	CS 2	Shuter	Valve	2023
2	Dota 2	Moba	Valve	2012
3	GTA 5	Open world	Rocstar Games	2012
4	FIFA2025	sport	EA	2025
5	APEX	CB	spavner	2020
\.


--
-- TOC entry 3398 (class 0 OID 63837)
-- Dependencies: 222
-- Data for Name: session_games; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session_games (session_id, game_id) FROM stdin;
\.


--
-- TOC entry 3402 (class 0 OID 72376)
-- Dependencies: 228
-- Data for Name: session_logs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.session_logs (log_id, session_id, log_time, message) FROM stdin;
\.


--
-- TOC entry 3395 (class 0 OID 63824)
-- Dependencies: 219
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sessions (session_id, client_id, computer_id, start_time, end_time, total_cost) FROM stdin;
1	1	1	2025-03-21 12:10:00+03	2025-03-21 14:10:00+03	400.00
2	2	2	2025-03-21 13:10:00+03	2025-03-21 16:10:00+03	500.00
3	3	3	2025-03-21 16:40:00+03	2025-03-21 19:00:00+03	300.00
4	4	4	2025-03-21 21:10:00+03	2025-03-21 23:10:00+03	600.00
5	5	5	2025-03-21 13:30:00+03	2025-03-21 16:10:00+03	900.00
\.


--
-- TOC entry 3414 (class 0 OID 0)
-- Dependencies: 225
-- Name: admins_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.admins_id_seq', 1, true);


--
-- TOC entry 3415 (class 0 OID 0)
-- Dependencies: 214
-- Name: clients_client_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clients_client_id_seq', 5, true);


--
-- TOC entry 3416 (class 0 OID 0)
-- Dependencies: 216
-- Name: computers _computer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public."computers _computer_id_seq"', 5, true);


--
-- TOC entry 3417 (class 0 OID 0)
-- Dependencies: 220
-- Name: games_game_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.games_game_id_seq', 5, true);


--
-- TOC entry 3418 (class 0 OID 0)
-- Dependencies: 227
-- Name: session_logs_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.session_logs_log_id_seq', 1, false);


--
-- TOC entry 3419 (class 0 OID 0)
-- Dependencies: 218
-- Name: sessions_session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sessions_session_id_seq', 5, true);


--
-- TOC entry 3237 (class 2606 OID 64141)
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- TOC entry 3229 (class 2606 OID 63813)
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (client_id);


--
-- TOC entry 3231 (class 2606 OID 63822)
-- Name: computers  computers _pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."computers "
    ADD CONSTRAINT "computers _pkey" PRIMARY KEY (computer_id);


--
-- TOC entry 3235 (class 2606 OID 63836)
-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (game_id);


--
-- TOC entry 3239 (class 2606 OID 72384)
-- Name: session_logs session_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_logs
    ADD CONSTRAINT session_logs_pkey PRIMARY KEY (log_id);


--
-- TOC entry 3233 (class 2606 OID 63829)
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (session_id);


--
-- TOC entry 3389 (class 2618 OID 64035)
-- Name: clientse delete_clientse; Type: RULE; Schema: public; Owner: postgres
--

CREATE RULE delete_clientse AS
    ON DELETE TO public.clientse DO INSTEAD  UPDATE public.clients SET visible = false
  WHERE (clients.client_id = old.client_id);


--
-- TOC entry 3244 (class 2620 OID 72387)
-- Name: sessions trg_check_session_duration; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_check_session_duration BEFORE INSERT OR UPDATE ON public.sessions FOR EACH ROW EXECUTE FUNCTION public.check_session_duration();


--
-- TOC entry 3240 (class 2606 OID 63840)
-- Name: sessions FK_sessins; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT "FK_sessins" FOREIGN KEY (client_id) REFERENCES public.clients(client_id) NOT VALID;


--
-- TOC entry 3241 (class 2606 OID 63845)
-- Name: sessions FK_sessins2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT "FK_sessins2" FOREIGN KEY (computer_id) REFERENCES public."computers "(computer_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3242 (class 2606 OID 63850)
-- Name: session_games FK_sgame; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_games
    ADD CONSTRAINT "FK_sgame" FOREIGN KEY (session_id) REFERENCES public.sessions(session_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 3243 (class 2606 OID 63855)
-- Name: session_games FK_sgame2; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.session_games
    ADD CONSTRAINT "FK_sgame2" FOREIGN KEY (game_id) REFERENCES public.games(game_id) ON DELETE CASCADE NOT VALID;


-- Completed on 2025-05-21 08:53:53

--
-- PostgreSQL database dump complete
--

