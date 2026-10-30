--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 17.2

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: alloydbsuperuser
--

-- *not* creating schema, since initdb creates it



--
-- Name: google_ml_integration; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION google_ml_integration; Type: COMMENT; Schema: -; Owner: 
--



--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


--
-- Name: alloydb_scann; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: EXTENSION alloydb_scann; Type: COMMENT; Schema: -; Owner: 
--



--
-- Name: google_columnar_engine; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: google_db_advisor; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: hypopg; Type: EXTENSION; Schema: -; Owner: -
--



--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: delivery_methods; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.delivery_methods (
    delivery_method_id integer NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    base_cost numeric(10,2) DEFAULT 0.00 NOT NULL,
    estimated_delivery_time character varying(100),
    store_id integer
);


ALTER TABLE public.delivery_methods OWNER TO postgres;

--
-- Name: delivery_methods_delivery_method_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.delivery_methods_delivery_method_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.delivery_methods_delivery_method_id_seq OWNER TO postgres;

--
-- Name: delivery_methods_delivery_method_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.delivery_methods_delivery_method_id_seq OWNED BY public.delivery_methods.delivery_method_id;


--
-- Name: inventory; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory (
    inventory_id integer NOT NULL,
    variant_id integer NOT NULL,
    store_id integer NOT NULL,
    quantity integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.inventory OWNER TO postgres;

--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventory_inventory_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventory_inventory_id_seq OWNER TO postgres;

--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventory_inventory_id_seq OWNED BY public.inventory.inventory_id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_items (
    order_item_id integer NOT NULL,
    order_id integer NOT NULL,
    variant_id integer NOT NULL,
    quantity integer NOT NULL,
    price_at_purchase numeric(10,2) NOT NULL,
    product_name_at_purchase character varying(255) NOT NULL,
    variant_details_at_purchase text,
    subtotal_line_item numeric(12,2) GENERATED ALWAYS AS (((quantity)::numeric * price_at_purchase)) STORED,
    CONSTRAINT order_items_quantity_check CHECK ((quantity > 0))
);


ALTER TABLE public.order_items OWNER TO postgres;

--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.order_items_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_order_item_id_seq OWNER TO postgres;

--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.order_items_order_item_id_seq OWNED BY public.order_items.order_item_id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    order_id integer NOT NULL,
    user_id integer NOT NULL,
    store_id integer,
    order_status character varying(50) DEFAULT 'pending'::character varying NOT NULL,
    shipping_address character varying(255),
    delivery_method_id integer,
    shipping_cost numeric(10,2) DEFAULT 0.00,
    total_amount numeric(12,2) NOT NULL
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: orders_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orders_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_order_id_seq OWNER TO postgres;

--
-- Name: orders_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orders_order_id_seq OWNED BY public.orders.order_id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    product_id integer NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    category character varying(255),
    brand character varying(255),
    image_url character varying(512),
    popularity_score double precision DEFAULT 0.0,
    embedding public.vector(768),
    search_vector tsvector GENERATED ALWAYS AS (((((((setweight(to_tsvector('english'::regconfig, (COALESCE(name, ''::character varying))::text), 'A'::"char") || ''::tsvector) || setweight(to_tsvector('english'::regconfig, (COALESCE(brand, ''::character varying))::text), 'A'::"char")) || ''::tsvector) || setweight(to_tsvector('english'::regconfig, (COALESCE(category, ''::character varying))::text), 'B'::"char")) || ''::tsvector) || setweight(to_tsvector('english'::regconfig, COALESCE(description, ''::text)), 'D'::"char"))) STORED
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_product_id_seq OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_product_id_seq OWNED BY public.products.product_id;


--
-- Name: products_variants; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products_variants (
    variant_id integer NOT NULL,
    product_id integer,
    size character varying(255) NOT NULL,
    color character varying(255) NOT NULL,
    price numeric(10,2) NOT NULL
);


ALTER TABLE public.products_variants OWNER TO postgres;

--
-- Name: products_variants_variant_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_variants_variant_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_variants_variant_id_seq OWNER TO postgres;

--
-- Name: products_variants_variant_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_variants_variant_id_seq OWNED BY public.products_variants.variant_id;


--
-- Name: shopping_list_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shopping_list_items (
    item_id integer NOT NULL,
    list_id integer,
    product_id integer,
    variant_id integer,
    quantity integer NOT NULL
);


ALTER TABLE public.shopping_list_items OWNER TO postgres;

--
-- Name: shopping_list_items_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shopping_list_items_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shopping_list_items_item_id_seq OWNER TO postgres;

--
-- Name: shopping_list_items_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shopping_list_items_item_id_seq OWNED BY public.shopping_list_items.item_id;


--
-- Name: shopping_lists; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.shopping_lists (
    list_id integer NOT NULL,
    user_id integer
);


ALTER TABLE public.shopping_lists OWNER TO postgres;

--
-- Name: shopping_lists_list_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.shopping_lists_list_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.shopping_lists_list_id_seq OWNER TO postgres;

--
-- Name: shopping_lists_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.shopping_lists_list_id_seq OWNED BY public.shopping_lists.list_id;


--
-- Name: stores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stores (
    store_id integer NOT NULL,
    name character varying(255) NOT NULL,
    address character varying(255),
    city character varying(100),
    postal_code character varying(20),
    country character varying(50) DEFAULT 'Spain'::character varying,
    popularity_score double precision DEFAULT 0.0,
    location public.geography(Point,4326)
);


ALTER TABLE public.stores OWNER TO postgres;

--
-- Name: stores_store_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stores_store_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stores_store_id_seq OWNER TO postgres;

--
-- Name: stores_store_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stores_store_id_seq OWNED BY public.stores.store_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    first_name character varying(100),
    last_name character varying(100),
    address character varying(255),
    city character varying(100),
    postal_code character varying(20),
    location public.geography(Point,4326),
    email character varying(255)
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: delivery_methods delivery_method_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_methods ALTER COLUMN delivery_method_id SET DEFAULT nextval('public.delivery_methods_delivery_method_id_seq'::regclass);


--
-- Name: inventory inventory_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory ALTER COLUMN inventory_id SET DEFAULT nextval('public.inventory_inventory_id_seq'::regclass);


--
-- Name: order_items order_item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items ALTER COLUMN order_item_id SET DEFAULT nextval('public.order_items_order_item_id_seq'::regclass);


--
-- Name: orders order_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders ALTER COLUMN order_id SET DEFAULT nextval('public.orders_order_id_seq'::regclass);


--
-- Name: products product_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products ALTER COLUMN product_id SET DEFAULT nextval('public.products_product_id_seq'::regclass);


--
-- Name: products_variants variant_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products_variants ALTER COLUMN variant_id SET DEFAULT nextval('public.products_variants_variant_id_seq'::regclass);


--
-- Name: shopping_list_items item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_list_items ALTER COLUMN item_id SET DEFAULT nextval('public.shopping_list_items_item_id_seq'::regclass);


--
-- Name: shopping_lists list_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_lists ALTER COLUMN list_id SET DEFAULT nextval('public.shopping_lists_list_id_seq'::regclass);


--
-- Name: stores store_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stores ALTER COLUMN store_id SET DEFAULT nextval('public.stores_store_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Data for Name: delivery_methods; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.delivery_methods (delivery_method_id, name, description, base_cost, estimated_delivery_time, store_id) FROM stdin;
1	Standard Home Delivery	Regular home delivery service within Barcelona metropolitan area	4.99	2-4 business days	1
2	Express Delivery	Same day delivery for orders before 2pm in Barcelona city	9.99	Same day delivery	1
3	Store Pickup	Pick up your order at Sports Gran Via 2	0.00	Ready in 2 hours	1
4	Standard Home Delivery	Regular home delivery service within Barcelona metropolitan area	4.99	2-4 business days	2
5	Express Delivery	Same day delivery for orders before 2pm in Barcelona city	9.99	Same day delivery	2
6	Store Pickup	Pick up your order at Sports L'illa Diagonal	0.00	Ready in 2 hours	2
7	Standard Home Delivery	Regular home delivery service within Barcelona metropolitan area	4.99	2-4 business days	3
8	Express Delivery	Same day delivery for orders before 2pm in Barcelona city	8.99	Same day delivery	3
9	Store Pickup	Pick up your order at Sports Ciutat Vella	0.00	Ready in 2 hours	3
10	Standard Home Delivery	Regular home delivery service within Barcelona metropolitan area	4.99	2-4 business days	4
11	Express Delivery	Same day delivery for orders before 2pm in Barcelona city	8.99	Same day delivery	4
12	Store Pickup	Pick up your order at Sports Gracia	0.00	Ready in 2 hours	4
13	Standard Home Delivery	Regular home delivery service within Barcelona metropolitan area	4.99	2-4 business days	5
14	Express Delivery	Same day delivery for orders before 2pm in Barcelona city	7.99	Same day delivery	5
15	Store Pickup	Pick up your order at Sports Diagonal Mar	0.00	Ready in 2 hours	5
16	Standard Home Delivery	Regular home delivery service within Barcelona metropolitan area	4.99	2-4 business days	6
17	Express Delivery	Same day delivery for orders before 2pm in Barcelona city	7.99	Same day delivery	6
18	Store Pickup	Pick up your order at Sports La Maquinista	0.00	Ready in 2 hours	6
\.


--
-- Data for Name: inventory; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory (inventory_id, variant_id, store_id, quantity) FROM stdin;
1	1	1	15
2	1	2	12
3	1	3	8
4	1	4	0
5	1	5	20
6	1	6	18
7	2	1	10
8	2	2	14
9	2	3	6
10	2	4	12
11	2	5	0
12	2	6	16
13	3	1	8
14	3	2	10
15	3	3	15
16	3	4	12
17	3	5	20
18	3	6	0
19	4	1	25
20	4	2	18
21	4	3	12
22	4	4	0
23	4	5	15
24	4	6	20
25	5	1	10
26	5	2	8
27	5	3	0
28	5	4	15
29	5	5	12
30	5	6	18
31	6	1	20
32	6	2	15
33	6	3	10
34	6	4	12
35	6	5	0
36	6	6	25
37	7	1	8
38	7	2	12
39	7	3	15
40	7	4	20
41	7	5	18
42	7	6	0
43	8	1	0
44	8	2	10
45	8	3	12
46	8	4	15
47	8	5	20
48	8	6	18
49	9	1	25
50	9	2	0
51	9	3	15
52	9	4	12
53	9	5	10
54	9	6	8
55	10	1	20
56	10	2	18
57	10	3	0
58	10	4	15
59	10	5	12
60	10	6	10
61	11	1	15
62	11	2	12
63	11	3	10
64	11	4	8
65	11	5	20
66	11	6	0
67	12	1	18
68	12	2	15
69	12	3	12
70	12	4	0
71	12	5	10
72	12	6	25
73	13	1	20
74	13	2	18
75	13	3	15
76	13	4	12
77	13	5	0
78	13	6	10
79	14	1	25
80	14	2	20
81	14	3	0
82	14	4	15
83	14	5	12
84	14	6	18
85	15	1	10
86	15	2	8
87	15	3	15
88	15	4	0
89	15	5	20
90	15	6	12
91	16	1	18
92	16	2	15
93	16	3	12
94	16	4	10
95	16	5	25
96	16	6	0
97	17	1	20
98	17	2	0
99	17	3	15
100	17	4	12
101	17	5	10
102	17	6	8
103	18	1	25
104	18	2	20
105	18	3	18
106	18	4	0
107	18	5	12
108	18	6	15
109	19	1	10
110	19	2	8
111	19	3	0
112	19	4	15
113	19	5	12
114	19	6	20
115	20	1	18
116	20	2	15
117	20	3	12
118	20	4	10
119	20	5	0
120	20	6	25
121	21	1	15
122	21	2	12
123	21	3	10
124	21	4	20
125	21	5	18
126	21	6	0
127	22	1	25
128	22	2	20
129	22	3	15
130	22	4	0
131	22	5	12
132	22	6	10
133	23	1	18
134	23	2	15
135	23	3	0
136	23	4	12
137	23	5	10
138	23	6	20
139	24	1	25
140	24	2	18
141	24	3	15
142	24	4	12
143	24	5	0
144	24	6	10
145	25	1	20
146	25	2	15
147	25	3	12
148	25	4	10
149	25	5	25
150	25	6	0
151	26	1	18
152	26	2	0
153	26	3	15
154	26	4	12
155	26	5	10
156	26	6	20
157	27	1	25
158	27	2	18
159	27	3	15
160	27	4	0
161	27	5	12
162	27	6	10
163	28	1	20
164	28	2	15
165	28	3	12
166	28	4	10
167	28	5	0
168	28	6	25
169	29	1	18
170	29	2	15
171	29	3	0
172	29	4	12
173	29	5	10
174	29	6	20
175	30	1	25
176	30	2	18
177	30	3	15
178	30	4	12
179	30	5	0
180	30	6	10
181	31	1	20
182	31	2	15
183	31	3	12
184	31	4	10
185	31	5	25
186	31	6	0
187	32	1	18
188	32	2	0
189	32	3	15
190	32	4	12
191	32	5	10
192	32	6	20
193	33	1	25
194	33	2	18
195	33	3	15
196	33	4	0
197	33	5	12
198	33	6	10
199	34	1	20
200	34	2	15
201	34	3	12
202	34	4	10
203	34	5	0
204	34	6	25
205	35	1	18
206	35	2	15
207	35	3	0
208	35	4	12
209	35	5	10
210	35	6	20
211	36	1	25
212	36	2	18
213	36	3	15
214	36	4	12
215	36	5	0
216	36	6	10
217	37	1	20
218	37	2	15
219	37	3	12
220	37	4	10
221	37	5	25
222	37	6	0
223	38	1	18
224	38	2	0
225	38	3	15
226	38	4	12
227	38	5	10
228	38	6	20
229	39	1	25
230	39	2	18
231	39	3	15
232	39	4	0
233	39	5	12
234	39	6	10
235	40	1	20
236	40	2	15
237	40	3	12
238	40	4	10
239	40	5	0
240	40	6	25
241	41	1	18
242	41	2	15
243	41	3	0
244	41	4	12
245	41	5	10
246	41	6	20
247	42	1	25
248	42	2	18
249	42	3	15
250	42	4	12
251	42	5	0
252	42	6	10
253	43	1	20
254	43	2	15
255	43	3	12
256	43	4	10
257	43	5	25
258	43	6	0
259	44	1	18
260	44	2	0
261	44	3	15
262	44	4	12
263	44	5	10
264	44	6	20
265	45	1	25
266	45	2	18
267	45	3	15
268	45	4	0
269	45	5	12
270	45	6	10
271	46	1	20
272	46	2	15
273	46	3	12
274	46	4	10
275	46	5	0
276	46	6	25
277	47	1	18
278	47	2	15
279	47	3	0
280	47	4	12
281	47	5	10
282	47	6	20
283	48	1	25
284	48	2	18
285	48	3	15
286	48	4	12
287	48	5	0
288	48	6	10
289	49	1	20
290	49	2	15
291	49	3	12
292	49	4	10
293	49	5	25
294	49	6	0
295	50	1	18
296	50	2	0
297	50	3	15
298	50	4	12
299	50	5	10
300	50	6	20
301	51	1	25
302	51	2	18
303	51	3	15
304	51	4	12
305	51	5	0
306	51	6	10
307	52	1	20
308	52	2	15
309	52	3	12
310	52	4	10
311	52	5	25
312	52	6	0
313	53	1	18
314	53	2	15
315	53	3	0
316	53	4	12
317	53	5	10
318	53	6	20
319	54	1	25
320	54	2	18
321	54	3	15
322	54	4	12
323	54	5	0
324	54	6	10
325	55	1	20
326	55	2	15
327	55	3	12
328	55	4	10
329	55	5	25
330	55	6	0
331	56	1	18
332	56	2	15
333	56	3	0
334	56	4	12
335	56	5	10
336	56	6	20
337	57	1	25
338	57	2	18
339	57	3	15
340	57	4	12
341	57	5	0
342	57	6	10
343	58	1	20
344	58	2	15
345	58	3	12
346	58	4	10
347	58	5	25
348	58	6	0
349	59	1	18
350	59	2	15
351	59	3	0
352	59	4	12
353	59	5	10
354	59	6	20
355	60	1	25
356	60	2	18
357	60	3	15
358	60	4	12
359	60	5	0
360	60	6	10
361	61	1	20
362	61	2	15
363	61	3	12
364	61	4	10
365	61	5	25
366	61	6	0
367	62	1	18
368	62	2	15
369	62	3	0
370	62	4	12
371	62	5	10
372	62	6	20
373	63	1	25
374	63	2	18
375	63	3	15
376	63	4	12
377	63	5	0
378	63	6	10
379	64	1	20
380	64	2	15
381	64	3	12
382	64	4	10
383	64	5	25
384	64	6	0
385	65	1	18
386	65	2	15
387	65	3	0
388	65	4	12
389	65	5	10
390	65	6	20
391	66	1	25
392	66	2	18
393	66	3	15
394	66	4	12
395	66	5	0
396	66	6	10
397	67	1	20
398	67	2	15
399	67	3	12
400	67	4	10
401	67	5	25
402	67	6	0
403	68	1	18
404	68	2	15
405	68	3	0
406	68	4	12
407	68	5	10
408	68	6	20
409	69	1	25
410	69	2	18
411	69	3	15
412	69	4	12
413	69	5	0
414	69	6	10
415	70	1	20
416	70	2	15
417	70	3	12
418	70	4	10
419	70	5	25
420	70	6	0
421	71	1	18
422	71	2	15
423	71	3	0
424	71	4	12
425	71	5	10
426	71	6	20
427	72	1	25
428	72	2	18
429	72	3	15
430	72	4	12
431	72	5	0
432	72	6	10
433	73	1	20
434	73	2	15
435	73	3	12
436	73	4	10
437	73	5	25
438	73	6	0
439	74	1	18
440	74	2	15
441	74	3	0
442	74	4	12
443	74	5	10
444	74	6	20
445	75	1	25
446	75	2	18
447	75	3	15
448	75	4	12
449	75	5	0
450	75	6	10
451	76	1	20
452	76	2	15
453	76	3	12
454	76	4	10
455	76	5	25
456	76	6	0
457	77	1	18
458	77	2	15
459	77	3	0
460	77	4	12
461	77	5	10
462	77	6	20
463	78	1	25
464	78	2	18
465	78	3	15
466	78	4	12
467	78	5	0
468	78	6	10
469	79	1	20
470	79	2	15
471	79	3	12
472	79	4	10
473	79	5	25
474	79	6	0
475	80	1	18
476	80	2	15
477	80	3	0
478	80	4	12
479	80	5	10
480	80	6	20
481	81	1	25
482	81	2	18
483	81	3	15
484	81	4	12
485	81	5	0
486	81	6	10
487	82	1	20
488	82	2	15
489	82	3	12
490	82	4	10
491	82	5	25
492	82	6	0
493	83	1	18
494	83	2	15
495	83	3	0
496	83	4	12
497	83	5	10
498	83	6	20
499	84	1	25
500	84	2	18
501	84	3	15
502	84	4	12
503	84	5	0
504	84	6	10
505	85	1	20
506	85	2	15
507	85	3	12
508	85	4	10
509	85	5	25
510	85	6	0
511	86	1	18
512	86	2	15
513	86	3	0
514	86	4	12
515	86	5	10
516	86	6	20
517	87	1	25
518	87	2	18
519	87	3	15
520	87	4	12
521	87	5	0
522	87	6	10
523	88	1	20
524	88	2	15
525	88	3	12
526	88	4	10
527	88	5	25
528	88	6	0
529	89	1	18
530	89	2	15
531	89	3	0
532	89	4	12
533	89	5	10
534	89	6	20
535	90	1	25
536	90	2	18
537	90	3	15
538	90	4	12
539	90	5	0
540	90	6	10
541	91	1	20
542	91	2	15
543	91	3	12
544	91	4	10
545	91	5	25
546	91	6	0
547	92	1	18
548	92	2	15
549	92	3	0
550	92	4	12
551	92	5	10
552	92	6	20
553	93	1	25
554	93	2	18
555	93	3	15
556	93	4	12
557	93	5	0
558	93	6	10
559	94	1	20
560	94	2	15
561	94	3	12
562	94	4	10
563	94	5	25
564	94	6	0
565	95	1	18
566	95	2	15
567	95	3	0
568	95	4	12
569	95	5	10
570	95	6	20
571	96	1	25
572	96	2	18
573	96	3	15
574	96	4	12
575	96	5	0
576	96	6	10
577	97	1	20
578	97	2	15
579	97	3	12
580	97	4	10
581	97	5	25
582	97	6	0
583	98	1	18
584	98	2	15
585	98	3	0
586	98	4	12
587	98	5	10
588	98	6	20
589	99	1	25
590	99	2	18
591	99	3	15
592	99	4	12
593	99	5	0
594	99	6	10
595	100	1	20
596	100	2	15
597	100	3	12
598	100	4	10
599	100	5	25
600	100	6	0
601	101	1	18
602	101	2	15
603	101	3	0
604	101	4	12
605	101	5	10
606	101	6	20
607	102	1	25
608	102	2	18
609	102	3	15
610	102	4	12
611	102	5	0
612	102	6	10
613	103	1	20
614	103	2	15
615	103	3	12
616	103	4	10
617	103	5	25
618	103	6	0
619	104	1	18
620	104	2	15
621	104	3	0
622	104	4	12
623	104	5	10
624	104	6	20
625	105	1	25
626	105	2	18
627	105	3	15
628	105	4	12
629	105	5	0
630	105	6	10
631	106	1	20
632	106	2	15
633	106	3	12
634	106	4	10
635	106	5	25
636	106	6	0
637	107	1	18
638	107	2	15
639	107	3	0
640	107	4	12
641	107	5	10
642	107	6	20
643	108	1	25
644	108	2	18
645	108	3	15
646	108	4	12
647	108	5	0
648	108	6	10
649	109	1	20
650	109	2	15
651	109	3	12
652	109	4	10
653	109	5	25
654	109	6	0
655	110	1	18
656	110	2	15
657	110	3	0
658	110	4	12
659	110	5	10
660	110	6	20
661	111	1	25
662	111	2	18
663	111	3	15
664	111	4	12
665	111	5	0
666	111	6	10
667	112	1	20
668	112	2	15
669	112	3	12
670	112	4	10
671	112	5	25
672	112	6	0
673	113	1	18
674	113	2	15
675	113	3	0
676	113	4	12
677	113	5	10
678	113	6	20
679	114	1	25
680	114	2	18
681	114	3	15
682	114	4	12
683	114	5	0
684	114	6	10
685	115	1	20
686	115	2	15
687	115	3	12
688	115	4	10
689	115	5	25
690	115	6	0
691	116	1	18
692	116	2	15
693	116	3	0
694	116	4	12
695	116	5	10
696	116	6	20
697	117	1	25
698	117	2	18
699	117	3	15
700	117	4	12
701	117	5	0
702	117	6	10
703	118	1	20
704	118	2	15
705	118	3	12
706	118	4	10
707	118	5	25
708	118	6	0
709	119	1	18
710	119	2	15
711	119	3	0
712	119	4	12
713	119	5	10
714	119	6	20
715	120	1	25
716	120	2	18
717	120	3	15
718	120	4	12
719	120	5	0
720	120	6	10
721	121	1	20
722	121	2	15
723	121	3	12
724	121	4	10
725	121	5	25
726	121	6	0
727	122	1	18
728	122	2	15
729	122	3	0
730	122	4	12
731	122	5	10
732	122	6	20
733	123	1	25
734	123	2	18
735	123	3	15
736	123	4	12
737	123	5	0
738	123	6	10
739	124	1	20
740	124	2	15
741	124	3	12
742	124	4	10
743	124	5	25
744	124	6	0
745	125	1	18
746	125	2	15
747	125	3	0
748	125	4	12
749	125	5	10
750	125	6	20
751	126	1	25
752	126	2	18
753	126	3	15
754	126	4	12
755	126	5	0
756	126	6	10
757	127	1	20
758	127	2	15
759	127	3	12
760	127	4	10
761	127	5	25
762	127	6	0
763	128	1	18
764	128	2	15
765	128	3	0
766	128	4	12
767	128	5	10
768	128	6	20
769	129	1	25
770	129	2	18
771	129	3	15
772	129	4	12
773	129	5	0
774	129	6	10
775	130	1	20
776	130	2	15
777	130	3	12
778	130	4	10
779	130	5	25
780	130	6	0
781	131	1	18
782	131	2	15
783	131	3	0
784	131	4	12
785	131	5	10
786	131	6	20
787	132	1	25
788	132	2	18
789	132	3	15
790	132	4	12
791	132	5	0
792	132	6	10
793	133	1	20
794	133	2	15
795	133	3	12
796	133	4	10
797	133	5	25
798	133	6	0
799	134	1	18
800	134	2	15
801	134	3	0
802	134	4	12
803	134	5	10
804	134	6	20
805	135	1	25
806	135	2	18
807	135	3	15
808	135	4	12
809	135	5	0
810	135	6	10
811	136	1	20
812	136	2	15
813	136	3	12
814	136	4	10
815	136	5	25
816	136	6	0
817	137	1	18
818	137	2	15
819	137	3	0
820	137	4	12
821	137	5	10
822	137	6	20
823	138	1	25
824	138	2	18
825	138	3	15
826	138	4	12
827	138	5	0
828	138	6	10
829	139	1	20
830	139	2	15
831	139	3	12
832	139	4	10
833	139	5	25
834	139	6	0
835	140	1	18
836	140	2	15
837	140	3	0
838	140	4	12
839	140	5	10
840	140	6	20
841	141	1	25
842	141	2	18
843	141	3	15
844	141	4	12
845	141	5	0
846	141	6	10
847	142	1	20
848	142	2	15
849	142	3	12
850	142	4	10
851	142	5	25
852	142	6	0
853	143	1	18
854	143	2	15
855	143	3	0
856	143	4	12
857	143	5	10
858	143	6	20
859	144	1	25
860	144	2	18
861	144	3	15
862	144	4	12
863	144	5	0
864	144	6	10
865	145	1	20
866	145	2	15
867	145	3	12
868	145	4	10
869	145	5	25
870	145	6	0
871	146	1	18
872	146	2	15
873	146	3	0
874	146	4	12
875	146	5	10
876	146	6	20
877	147	1	25
878	147	2	18
879	147	3	15
880	147	4	12
881	147	5	0
882	147	6	10
883	148	1	20
884	148	2	15
885	148	3	12
886	148	4	10
887	148	5	25
888	148	6	0
889	149	1	18
890	149	2	15
891	149	3	0
892	149	4	12
893	149	5	10
894	149	6	20
895	150	1	25
896	150	2	18
897	150	3	15
898	150	4	12
899	150	5	0
900	150	6	10
901	151	1	20
902	151	2	15
903	151	3	12
904	151	4	10
905	151	5	25
906	151	6	0
907	152	1	18
908	152	2	15
909	152	3	0
910	152	4	12
911	152	5	10
912	152	6	20
913	153	1	25
914	153	2	18
915	153	3	15
916	153	4	12
917	153	5	0
918	153	6	10
919	154	1	20
920	154	2	15
921	154	3	12
922	154	4	10
923	154	5	25
924	154	6	0
925	155	1	18
926	155	2	15
927	155	3	0
928	155	4	12
929	155	5	10
930	155	6	20
931	156	1	25
932	156	2	18
933	156	3	15
934	156	4	12
935	156	5	0
936	156	6	10
937	157	1	20
938	157	2	15
939	157	3	12
940	157	4	10
941	157	5	25
942	157	6	0
943	158	1	18
944	158	2	15
945	158	3	0
946	158	4	12
947	158	5	10
948	158	6	20
949	159	1	25
950	159	2	18
951	159	3	15
952	159	4	12
953	159	5	0
954	159	6	10
955	160	1	20
956	160	2	15
957	160	3	12
958	160	4	10
959	160	5	25
960	160	6	0
961	161	1	18
962	161	2	15
963	161	3	0
964	161	4	12
965	161	5	10
966	161	6	20
967	162	1	25
968	162	2	18
969	162	3	15
970	162	4	12
971	162	5	0
972	162	6	10
973	163	1	20
974	163	2	15
975	163	3	12
976	163	4	10
977	163	5	25
978	163	6	0
979	164	1	18
980	164	2	15
981	164	3	0
982	164	4	12
983	164	5	10
984	164	6	20
985	165	1	25
986	165	2	18
987	165	3	15
988	165	4	12
989	165	5	0
990	165	6	10
991	166	1	20
992	166	2	15
993	166	3	12
994	166	4	10
995	166	5	25
996	166	6	0
997	167	1	18
998	167	2	15
999	167	3	0
1000	167	4	12
1001	167	5	10
1002	167	6	20
1003	168	1	25
1004	168	2	18
1005	168	3	15
1006	168	4	12
1007	168	5	0
1008	168	6	10
1009	169	1	20
1010	169	2	15
1011	169	3	12
1012	169	4	10
1013	169	5	25
1014	169	6	0
1015	170	1	18
1016	170	2	15
1017	170	3	0
1018	170	4	12
1019	170	5	10
1020	170	6	20
1021	171	1	25
1022	171	2	18
1023	171	3	15
1024	171	4	12
1025	171	5	0
1026	171	6	10
1027	172	1	20
1028	172	2	15
1029	172	3	12
1030	172	4	10
1031	172	5	25
1032	172	6	0
1033	173	1	18
1034	173	2	15
1035	173	3	0
1036	173	4	12
1037	173	5	10
1038	173	6	20
1039	174	1	25
1040	174	2	18
1041	174	3	15
1042	174	4	12
1043	174	5	0
1044	174	6	10
1045	175	1	20
1046	175	2	15
1047	175	3	12
1048	175	4	10
1049	175	5	25
1050	175	6	0
1051	176	1	18
1052	176	2	15
1053	176	3	0
1054	176	4	12
1055	176	5	10
1056	176	6	20
1057	177	1	25
1058	177	2	18
1059	177	3	15
1060	177	4	12
1061	177	5	0
1062	177	6	10
1063	178	1	20
1064	178	2	15
1065	178	3	12
1066	178	4	10
1067	178	5	25
1068	178	6	0
1069	179	1	18
1070	179	2	15
1071	179	3	0
1072	179	4	12
1073	179	5	10
1074	179	6	20
1075	180	1	25
1076	180	2	18
1077	180	3	15
1078	180	4	12
1079	180	5	0
1080	180	6	10
1081	181	1	20
1082	181	2	15
1083	181	3	12
1084	181	4	10
1085	181	5	25
1086	181	6	0
1087	182	1	18
1088	182	2	15
1089	182	3	0
1090	182	4	12
1091	182	5	10
1092	182	6	20
1093	183	1	25
1094	183	2	18
1095	183	3	15
1096	183	4	12
1097	183	5	0
1098	183	6	10
1099	184	1	20
1100	184	2	15
1101	184	3	12
1102	184	4	10
1103	184	5	25
1104	184	6	0
1105	185	1	18
1106	185	2	15
1107	185	3	0
1108	185	4	12
1109	185	5	10
1110	185	6	20
1111	186	1	25
1112	186	2	18
1113	186	3	15
1114	186	4	12
1115	186	5	0
1116	186	6	10
1117	187	1	20
1118	187	2	15
1119	187	3	12
1120	187	4	10
1121	187	5	25
1122	187	6	0
1123	188	1	18
1124	188	2	15
1125	188	3	0
1126	188	4	12
1127	188	5	10
1128	188	6	20
1129	189	1	25
1130	189	2	18
1131	189	3	15
1132	189	4	12
1133	189	5	0
1134	189	6	10
1135	190	1	20
1136	190	2	15
1137	190	3	12
1138	190	4	10
1139	190	5	25
1140	190	6	0
1141	191	1	18
1142	191	2	15
1143	191	3	0
1144	191	4	12
1145	191	5	10
1146	191	6	20
1147	192	1	25
1148	192	2	18
1149	192	3	15
1150	192	4	12
1151	192	5	0
1152	192	6	10
1153	193	1	20
1154	193	2	15
1155	193	3	12
1156	193	4	10
1157	193	5	25
1158	193	6	0
1159	194	1	18
1160	194	2	15
1161	194	3	0
1162	194	4	12
1163	194	5	10
1164	194	6	20
1165	195	1	25
1166	195	2	18
1167	195	3	15
1168	195	4	12
1169	195	5	0
1170	195	6	10
1171	196	1	20
1172	196	2	15
1173	196	3	12
1174	196	4	10
1175	196	5	25
1176	196	6	0
1177	197	1	18
1178	197	2	15
1179	197	3	0
1180	197	4	12
1181	197	5	10
1182	197	6	20
1183	198	1	25
1184	198	2	18
1185	198	3	15
1186	198	4	12
1187	198	5	0
1188	198	6	10
1189	199	1	20
1190	199	2	15
1191	199	3	12
1192	199	4	10
1193	199	5	25
1194	199	6	0
1195	200	1	18
1196	200	2	15
1197	200	3	0
1198	200	4	12
1199	200	5	10
1200	200	6	20
1201	201	1	25
1202	201	2	18
1203	201	3	15
1204	201	4	12
1205	201	5	0
1206	201	6	10
1207	202	1	20
1208	202	2	15
1209	202	3	12
1210	202	4	10
1211	202	5	25
1212	202	6	0
1213	203	1	18
1214	203	2	15
1215	203	3	0
1216	203	4	12
1217	203	5	10
1218	203	6	20
1219	204	1	25
1220	204	2	18
1221	204	3	15
1222	204	4	12
1223	204	5	0
1224	204	6	10
1225	205	1	20
1226	205	2	15
1227	205	3	12
1228	205	4	10
1229	205	5	25
1230	205	6	0
1231	206	1	18
1232	206	2	15
1233	206	3	0
1234	206	4	12
1235	206	5	10
1236	206	6	20
1237	207	1	25
1238	207	2	18
1239	207	3	15
1240	207	4	12
1241	207	5	0
1242	207	6	10
1243	208	1	20
1244	208	2	15
1245	208	3	12
1246	208	4	10
1247	208	5	25
1248	208	6	0
1249	209	1	18
1250	209	2	15
1251	209	3	0
1252	209	4	12
1253	209	5	10
1254	209	6	20
1255	210	1	25
1256	210	2	18
1257	210	3	15
1258	210	4	12
1259	210	5	0
1260	210	6	10
1261	211	1	20
1262	211	2	15
1263	211	3	12
1264	211	4	10
1265	211	5	25
1266	211	6	0
1267	212	1	18
1268	212	2	15
1269	212	3	0
1270	212	4	12
1271	212	5	10
1272	212	6	20
1273	213	1	25
1274	213	2	18
1275	213	3	15
1276	213	4	12
1277	213	5	0
1278	213	6	10
1279	214	1	20
1280	214	2	15
1281	214	3	12
1282	214	4	10
1283	214	5	25
1284	214	6	0
1285	215	1	18
1286	215	2	15
1287	215	3	0
1288	215	4	12
1289	215	5	10
1290	215	6	20
1291	216	1	25
1292	216	2	18
1293	216	3	15
1294	216	4	12
1295	216	5	0
1296	216	6	10
1297	217	1	20
1298	217	2	15
1299	217	3	12
1300	217	4	10
1301	217	5	25
1302	217	6	0
1303	218	1	18
1304	218	2	15
1305	218	3	0
1306	218	4	12
1307	218	5	10
1308	218	6	20
1309	219	1	25
1310	219	2	18
1311	219	3	15
1312	219	4	12
1313	219	5	0
1314	219	6	10
1315	220	1	20
1316	220	2	15
1317	220	3	12
1318	220	4	10
1319	220	5	25
1320	220	6	0
1321	221	1	18
1322	221	2	15
1323	221	3	0
1324	221	4	12
1325	221	5	10
1326	221	6	20
1327	222	1	25
1328	222	2	18
1329	222	3	15
1330	222	4	12
1331	222	5	0
1332	222	6	10
1333	223	1	20
1334	223	2	15
1335	223	3	12
1336	223	4	10
1337	223	5	25
1338	223	6	0
1339	224	1	18
1340	224	2	15
1341	224	3	0
1342	224	4	12
1343	224	5	10
1344	224	6	20
1345	225	1	25
1346	225	2	18
1347	225	3	15
1348	225	4	12
1349	225	5	0
1350	225	6	10
1351	226	1	20
1352	226	2	15
1353	226	3	12
1354	226	4	10
1355	226	5	25
1356	226	6	0
1357	227	1	18
1358	227	2	15
1359	227	3	0
1360	227	4	12
1361	227	5	10
1362	227	6	20
1363	228	1	25
1364	228	2	18
1365	228	3	15
1366	228	4	12
1367	228	5	0
1368	228	6	10
1369	229	1	20
1370	229	2	15
1371	229	3	12
1372	229	4	10
1373	229	5	25
1374	229	6	0
1375	230	1	18
1376	230	2	15
1377	230	3	0
1378	230	4	12
1379	230	5	10
1380	230	6	20
1381	231	1	25
1382	231	2	18
1383	231	3	15
1384	231	4	12
1385	231	5	0
1386	231	6	10
1387	232	1	20
1388	232	2	15
1389	232	3	12
1390	232	4	10
1391	232	5	25
1392	232	6	0
1393	233	1	18
1394	233	2	15
1395	233	3	0
1396	233	4	12
1397	233	5	10
1398	233	6	20
1399	234	1	25
1400	234	2	18
1401	234	3	15
1402	234	4	12
1403	234	5	0
1404	234	6	10
1405	235	1	20
1406	235	2	15
1407	235	3	12
1408	235	4	10
1409	235	5	25
1410	235	6	0
1411	236	1	18
1412	236	2	15
1413	236	3	0
1414	236	4	12
1415	236	5	10
1416	236	6	20
1417	237	1	25
1418	237	2	18
1419	237	3	15
1420	237	4	12
1421	237	5	0
1422	237	6	10
1423	238	1	20
1424	238	2	15
1425	238	3	12
1426	238	4	10
1427	238	5	25
1428	238	6	0
1429	239	1	18
1430	239	2	15
1431	239	3	0
1432	239	4	12
1433	239	5	10
1434	239	6	20
1435	240	1	25
1436	240	2	18
1437	240	3	15
1438	240	4	12
1439	240	5	0
1440	240	6	10
1441	241	1	20
1442	241	2	15
1443	241	3	12
1444	241	4	10
1445	241	5	25
1446	241	6	0
1447	242	1	18
1448	242	2	15
1449	242	3	0
1450	242	4	12
1451	242	5	10
1452	242	6	20
1453	243	1	25
1454	243	2	18
1455	243	3	15
1456	243	4	12
1457	243	5	0
1458	243	6	10
1459	244	1	20
1460	244	2	15
1461	244	3	12
1462	244	4	10
1463	244	5	25
1464	244	6	0
1465	245	1	18
1466	245	2	15
1467	245	3	0
1468	245	4	12
1469	245	5	10
1470	245	6	20
1471	246	1	25
1472	246	2	18
1473	246	3	15
1474	246	4	12
1475	246	5	0
1476	246	6	10
1477	247	1	20
1478	247	2	15
1479	247	3	12
1480	247	4	10
1481	247	5	25
1482	247	6	0
1483	248	1	18
1484	248	2	15
1485	248	3	0
1486	248	4	12
1487	248	5	10
1488	248	6	20
1489	249	1	25
1490	249	2	18
1491	249	3	15
1492	249	4	12
1493	249	5	0
1494	249	6	10
1495	250	1	20
1496	250	2	15
1497	250	3	12
1498	250	4	10
1499	250	5	25
1500	250	6	0
1501	251	1	18
1502	251	2	15
1503	251	3	0
1504	251	4	12
1505	251	5	10
1506	251	6	20
1507	252	1	25
1508	252	2	18
1509	252	3	15
1510	252	4	12
1511	252	5	0
1512	252	6	10
1513	253	1	20
1514	253	2	15
1515	253	3	12
1516	253	4	10
1517	253	5	25
1518	253	6	0
1519	254	1	18
1520	254	2	15
1521	254	3	0
1522	254	4	12
1523	254	5	10
1524	254	6	20
1525	255	1	25
1526	255	2	18
1527	255	3	15
1528	255	4	12
1529	255	5	0
1530	255	6	10
1531	256	1	20
1532	256	2	15
1533	256	3	12
1534	256	4	10
1535	256	5	25
1536	256	6	0
1537	257	1	18
1538	257	2	15
1539	257	3	0
1540	257	4	12
1541	257	5	10
1542	257	6	20
1543	258	1	25
1544	258	2	18
1545	258	3	15
1546	258	4	12
1547	258	5	0
1548	258	6	10
1549	259	1	20
1550	259	2	15
1551	259	3	12
1552	259	4	10
1553	259	5	25
1554	259	6	0
1555	260	1	18
1556	260	2	15
1557	260	3	0
1558	260	4	12
1559	260	5	10
1560	260	6	20
1561	261	1	25
1562	261	2	18
1563	261	3	15
1564	261	4	12
1565	261	5	0
1566	261	6	10
1567	262	1	20
1568	262	2	15
1569	262	3	12
1570	262	4	10
1571	262	5	25
1572	262	6	0
1573	263	1	18
1574	263	2	15
1575	263	3	0
1576	263	4	12
1577	263	5	10
1578	263	6	20
1579	264	1	25
1580	264	2	18
1581	264	3	15
1582	264	4	12
1583	264	5	0
1584	264	6	10
1585	265	1	20
1586	265	2	15
1587	265	3	12
1588	265	4	10
1589	265	5	25
1590	265	6	0
1591	266	1	18
1592	266	2	15
1593	266	3	0
1594	266	4	12
1595	266	5	10
1596	266	6	20
1597	267	1	25
1598	267	2	18
1599	267	3	15
1600	267	4	12
1601	267	5	0
1602	267	6	10
1603	268	1	20
1604	268	2	15
1605	268	3	12
1606	268	4	10
1607	268	5	25
1608	268	6	0
1609	269	1	18
1610	269	2	15
1611	269	3	0
1612	269	4	12
1613	269	5	10
1614	269	6	20
1615	270	1	25
1616	270	2	18
1617	270	3	15
1618	270	4	12
1619	270	5	0
1620	270	6	10
1621	271	1	20
1622	271	2	15
1623	271	3	12
1624	271	4	10
1625	271	5	25
1626	271	6	0
1627	272	1	18
1628	272	2	15
1629	272	3	0
1630	272	4	12
1631	272	5	10
1632	272	6	20
1633	273	1	25
1634	273	2	18
1635	273	3	15
1636	273	4	12
1637	273	5	0
1638	273	6	10
1639	274	1	20
1640	274	2	15
1641	274	3	12
1642	274	4	10
1643	274	5	25
1644	274	6	0
1645	275	1	18
1646	275	2	15
1647	275	3	0
1648	275	4	12
1649	275	5	10
1650	275	6	20
1651	276	1	25
1652	276	2	18
1653	276	3	15
1654	276	4	12
1655	276	5	0
1656	276	6	10
1657	277	1	20
1658	277	2	15
1659	277	3	12
1660	277	4	10
1661	277	5	25
1662	277	6	0
1663	278	1	18
1664	278	2	15
1665	278	3	0
1666	278	4	12
1667	278	5	10
1668	278	6	20
1669	279	1	25
1670	279	2	18
1671	279	3	15
1672	279	4	12
1673	279	5	0
1674	279	6	10
1675	280	1	20
1676	280	2	15
1677	280	3	12
1678	280	4	10
1679	280	5	25
1680	280	6	0
1681	281	1	18
1682	281	2	15
1683	281	3	0
1684	281	4	12
1685	281	5	10
1686	281	6	20
1687	282	1	25
1688	282	2	18
1689	282	3	15
1690	282	4	12
1691	282	5	0
1692	282	6	10
1693	283	1	20
1694	283	2	15
1695	283	3	12
1696	283	4	10
1697	283	5	25
1698	283	6	0
1699	284	1	18
1700	284	2	15
1701	284	3	0
1702	284	4	12
1703	284	5	10
1704	284	6	20
1705	285	1	25
1706	285	2	18
1707	285	3	15
1708	285	4	12
1709	285	5	0
1710	285	6	10
1711	286	1	20
1712	286	2	15
1713	286	3	12
1714	286	4	10
1715	286	5	25
1716	286	6	0
1717	287	1	18
1718	287	2	15
1719	287	3	0
1720	287	4	12
1721	287	5	10
1722	287	6	20
1723	288	1	25
1724	288	2	18
1725	288	3	15
1726	288	4	12
1727	288	5	0
1728	288	6	10
1729	289	1	20
1730	289	2	15
1731	289	3	12
1732	289	4	10
1733	289	5	25
1734	289	6	0
1735	290	1	18
1736	290	2	15
1737	290	3	0
1738	290	4	12
1739	290	5	10
1740	290	6	20
1741	291	1	25
1742	291	2	18
1743	291	3	15
1744	291	4	12
1745	291	5	0
1746	291	6	10
1747	292	1	20
1748	292	2	15
1749	292	3	12
1750	292	4	10
1751	292	5	25
1752	292	6	0
1753	293	1	18
1754	293	2	15
1755	293	3	0
1756	293	4	12
1757	293	5	10
1758	293	6	20
1759	294	1	25
1760	294	2	18
1761	294	3	15
1762	294	4	12
1763	294	5	0
1764	294	6	10
1765	295	1	20
1766	295	2	15
1767	295	3	12
1768	295	4	10
1769	295	5	25
1770	295	6	0
1771	296	1	18
1772	296	2	15
1773	296	3	0
1774	296	4	12
1775	296	5	10
1776	296	6	20
1777	297	1	25
1778	297	2	18
1779	297	3	15
1780	297	4	12
1781	297	5	0
1782	297	6	10
1783	298	1	20
1784	298	2	15
1785	298	3	12
1786	298	4	10
1787	298	5	25
1788	298	6	0
1789	299	1	18
1790	299	2	15
1791	299	3	0
1792	299	4	12
1793	299	5	10
1794	299	6	20
1795	300	1	25
1796	300	2	18
1797	300	3	15
1798	300	4	12
1799	300	5	0
1800	300	6	10
1801	301	1	20
1802	301	2	15
1803	301	3	12
1804	301	4	10
1805	301	5	25
1806	301	6	0
1807	302	1	18
1808	302	2	15
1809	302	3	0
1810	302	4	12
1811	302	5	10
1812	302	6	20
1813	303	1	25
1814	303	2	18
1815	303	3	15
1816	303	4	12
1817	303	5	0
1818	303	6	10
1819	304	1	20
1820	304	2	15
1821	304	3	12
1822	304	4	10
1823	304	5	25
1824	304	6	0
1825	305	1	18
1826	305	2	15
1827	305	3	0
1828	305	4	12
1829	305	5	10
1830	305	6	20
1831	306	1	25
1832	306	2	18
1833	306	3	15
1834	306	4	12
1835	306	5	0
1836	306	6	10
1837	307	1	20
1838	307	2	15
1839	307	3	12
1840	307	4	10
1841	307	5	25
1842	307	6	0
1843	308	1	18
1844	308	2	15
1845	308	3	0
1846	308	4	12
1847	308	5	10
1848	308	6	20
1849	309	1	25
1850	309	2	18
1851	309	3	15
1852	309	4	12
1853	309	5	0
1854	309	6	10
1855	310	1	20
1856	310	2	15
1857	310	3	12
1858	310	4	10
1859	310	5	25
1860	310	6	0
1861	311	1	18
1862	311	2	15
1863	311	3	0
1864	311	4	12
1865	311	5	10
1866	311	6	20
1867	312	1	25
1868	312	2	18
1869	312	3	15
1870	312	4	12
1871	312	5	0
1872	312	6	10
1873	313	1	20
1874	313	2	15
1875	313	3	12
1876	313	4	10
1877	313	5	25
1878	313	6	0
1879	314	1	18
1880	314	2	15
1881	314	3	0
1882	314	4	12
1883	314	5	10
1884	314	6	20
1885	315	1	25
1886	315	2	18
1887	315	3	15
1888	315	4	12
1889	315	5	0
1890	315	6	10
1891	316	1	20
1892	316	2	15
1893	316	3	12
1894	316	4	10
1895	316	5	25
1896	316	6	0
1897	317	1	18
1898	317	2	15
1899	317	3	0
1900	317	4	12
1901	317	5	10
1902	317	6	20
1903	318	1	25
1904	318	2	18
1905	318	3	15
1906	318	4	12
1907	318	5	0
1908	318	6	10
1909	319	1	20
1910	319	2	15
1911	319	3	12
1912	319	4	10
1913	319	5	25
1914	319	6	0
1915	320	1	18
1916	320	2	15
1917	320	3	0
1918	320	4	12
1919	320	5	10
1920	320	6	20
1921	321	1	25
1922	321	2	18
1923	321	3	15
1924	321	4	12
1925	321	5	0
1926	321	6	10
1927	322	1	20
1928	322	2	15
1929	322	3	12
1930	322	4	10
1931	322	5	25
1932	322	6	0
1933	323	1	18
1934	323	2	15
1935	323	3	0
1936	323	4	12
1937	323	5	10
1938	323	6	20
1939	324	1	25
1940	324	2	18
1941	324	3	15
1942	324	4	12
1943	324	5	0
1944	324	6	10
1945	325	1	20
1946	325	2	15
1947	325	3	12
1948	325	4	10
1949	325	5	25
1950	325	6	0
1951	326	1	18
1952	326	2	15
1953	326	3	0
1954	326	4	12
1955	326	5	10
1956	326	6	20
1957	327	1	25
1958	327	2	18
1959	327	3	15
1960	327	4	12
1961	327	5	0
1962	327	6	10
1963	328	1	20
1964	328	2	15
1965	328	3	12
1966	328	4	10
1967	328	5	25
1968	328	6	0
1969	329	1	18
1970	329	2	15
1971	329	3	0
1972	329	4	12
1973	329	5	10
1974	329	6	20
1975	330	1	25
1976	330	2	18
1977	330	3	15
1978	330	4	12
1979	330	5	0
1980	330	6	10
1981	331	1	20
1982	331	2	15
1983	331	3	12
1984	331	4	10
1985	331	5	25
1986	331	6	0
1987	332	1	18
1988	332	2	15
1989	332	3	0
1990	332	4	12
1991	332	5	10
1992	332	6	20
1993	333	1	25
1994	333	2	18
1995	333	3	15
1996	333	4	12
1997	333	5	0
1998	333	6	10
1999	334	1	20
2000	334	2	15
2001	334	3	12
2002	334	4	10
2003	334	5	25
2004	334	6	0
2005	335	1	18
2006	335	2	15
2007	335	3	0
2008	335	4	12
2009	335	5	10
2010	335	6	20
2011	336	1	25
2012	336	2	18
2013	336	3	15
2014	336	4	12
2015	336	5	0
2016	336	6	10
2017	337	1	20
2018	337	2	15
2019	337	3	12
2020	337	4	10
2021	337	5	25
2022	337	6	0
2023	338	1	18
2024	338	2	15
2025	338	3	0
2026	338	4	12
2027	338	5	10
2028	338	6	20
2029	339	1	25
2030	339	2	18
2031	339	3	15
2032	339	4	12
2033	339	5	0
2034	339	6	10
2035	340	1	20
2036	340	2	15
2037	340	3	12
2038	340	4	10
2039	340	5	25
2040	340	6	0
2041	341	1	18
2042	341	2	15
2043	341	3	0
2044	341	4	12
2045	341	5	10
2046	341	6	20
2047	342	1	25
2048	342	2	18
2049	342	3	15
2050	342	4	12
2051	342	5	0
2052	342	6	10
2053	343	1	20
2054	343	2	15
2055	343	3	12
2056	343	4	10
2057	343	5	25
2058	343	6	0
2059	344	1	18
2060	344	2	15
2061	344	3	0
2062	344	4	12
2063	344	5	10
2064	344	6	20
2065	345	1	25
2066	345	2	18
2067	345	3	15
2068	345	4	12
2069	345	5	0
2070	345	6	10
2071	346	1	20
2072	346	2	15
2073	346	3	12
2074	346	4	10
2075	346	5	25
2076	346	6	0
2077	347	1	18
2078	347	2	15
2079	347	3	0
2080	347	4	12
2081	347	5	10
2082	347	6	20
2083	348	1	25
2084	348	2	18
2085	348	3	15
2086	348	4	12
2087	348	5	0
2088	348	6	10
2089	349	1	20
2090	349	2	15
2091	349	3	12
2092	349	4	10
2093	349	5	25
2094	349	6	0
2095	350	1	18
2096	350	2	15
2097	350	3	0
2098	350	4	12
2099	350	5	10
2100	350	6	20
2101	351	1	25
2102	351	2	18
2103	351	3	15
2104	351	4	12
2105	351	5	0
2106	351	6	10
2107	352	1	20
2108	352	2	15
2109	352	3	12
2110	352	4	10
2111	352	5	25
2112	352	6	0
2113	353	1	18
2114	353	2	15
2115	353	3	0
2116	353	4	12
2117	353	5	10
2118	353	6	20
2119	354	1	25
2120	354	2	18
2121	354	3	15
2122	354	4	12
2123	354	5	0
2124	354	6	10
2125	355	1	20
2126	355	2	15
2127	355	3	12
2128	355	4	10
2129	355	5	25
2130	355	6	0
2131	356	1	18
2132	356	2	15
2133	356	3	0
2134	356	4	12
2135	356	5	10
2136	356	6	20
2137	357	1	25
2138	357	2	18
2139	357	3	15
2140	357	4	12
2141	357	5	0
2142	357	6	10
2143	358	1	20
2144	358	2	15
2145	358	3	12
2146	358	4	10
2147	358	5	25
2148	358	6	0
2149	359	1	18
2150	359	2	15
2151	359	3	0
2152	359	4	12
2153	359	5	10
2154	359	6	20
2155	360	1	25
2156	360	2	18
2157	360	3	15
2158	360	4	12
2159	360	5	0
2160	360	6	10
2161	361	1	20
2162	361	2	15
2163	361	3	12
2164	361	4	10
2165	361	5	25
2166	361	6	0
2167	362	1	18
2168	362	2	15
2169	362	3	0
2170	362	4	12
2171	362	5	10
2172	362	6	20
2173	363	1	25
2174	363	2	18
2175	363	3	15
2176	363	4	12
2177	363	5	0
2178	363	6	10
2179	364	1	20
2180	364	2	15
2181	364	3	12
2182	364	4	10
2183	364	5	25
2184	364	6	0
2185	365	1	18
2186	365	2	15
2187	365	3	0
2188	365	4	12
2189	365	5	10
2190	365	6	20
2191	366	1	25
2192	366	2	18
2193	366	3	15
2194	366	4	12
2195	366	5	0
2196	366	6	10
2197	367	1	20
2198	367	2	15
2199	367	3	12
2200	367	4	10
2201	367	5	25
2202	367	6	0
2203	368	1	18
2204	368	2	15
2205	368	3	0
2206	368	4	12
2207	368	5	10
2208	368	6	20
2209	369	1	25
2210	369	2	18
2211	369	3	15
2212	369	4	12
2213	369	5	0
2214	369	6	10
2215	370	1	20
2216	370	2	15
2217	370	3	12
2218	370	4	10
2219	370	5	25
2220	370	6	0
2221	371	1	18
2222	371	2	15
2223	371	3	0
2224	371	4	12
2225	371	5	10
2226	371	6	20
2227	372	1	25
2228	372	2	18
2229	372	3	15
2230	372	4	12
2231	372	5	0
2232	372	6	10
2233	373	1	20
2234	373	2	15
2235	373	3	12
2236	373	4	10
2237	373	5	25
2238	373	6	0
2239	374	1	18
2240	374	2	15
2241	374	3	0
2242	374	4	12
2243	374	5	10
2244	374	6	20
2245	375	1	25
2246	375	2	18
2247	375	3	15
2248	375	4	12
2249	375	5	0
2250	375	6	10
2251	376	1	20
2252	376	2	15
2253	376	3	12
2254	376	4	10
2255	376	5	25
2256	376	6	0
2257	377	1	18
2258	377	2	15
2259	377	3	0
2260	377	4	12
2261	377	5	10
2262	377	6	20
2263	378	1	25
2264	378	2	18
2265	378	3	15
2266	378	4	12
2267	378	5	0
2268	378	6	10
2269	379	1	20
2270	379	2	15
2271	379	3	12
2272	379	4	10
2273	379	5	25
2274	379	6	0
2275	380	1	18
2276	380	2	15
2277	380	3	0
2278	380	4	12
2279	380	5	10
2280	380	6	20
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_items (order_item_id, order_id, variant_id, quantity, price_at_purchase, product_name_at_purchase, variant_details_at_purchase) FROM stdin;
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (order_id, user_id, store_id, order_status, shipping_address, delivery_method_id, shipping_cost, total_amount) FROM stdin;
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (product_id, name, description, category, brand, image_url, popularity_score, embedding) FROM stdin;
37	More v4	Maximum cushioned trainer with Fresh Foam X midsole and breathable upper. Plush comfort for recovery runs.	Running	New Balance	images/More v4.png	4.6	\N
2	Ghost 15	Women's neutral running shoe featuring DNA LOFT cushioning and engineered air mesh upper. Ideal for road running with excellent shock absorption.	Running	Brooks	images/Ghost 15.png	4.7	\N
3	Speedgoat 5	Trail running shoes with Vibram® Megagrip outsole and waterproof Gore-Tex membrane. Maximum cushioning for technical terrain.	Running	Hoka	images/Speedgoat 5.png	4.6	\N
4	Trek 500	50L hiking backpack with adjustable back system, rain cover, and multiple compartments. Water-resistant fabric and comfortable padded straps.	Hiking and Camp	Quechua	images/Trek 500.png	4.5	\N
5	Osprey Atmos AG 65	65L backpack featuring Anti-Gravity suspension, integrated rain cover, and multiple access points. Perfect for multi-day treks.	Hiking and Camp	Osprey	images/Osprey Atmos AG 65.png	4.9	\N
7	Hubba Hubba NX	3-season 2-person tent with DAC Featherlite poles, DWR-coated ripstop nylon, and vestibules for gear storage. Freestanding design.	Hiking and Camp	MSR	images/Hubba Hubba NX.png	4.8	\N
8	Aether Pro 70	70L expedition backpack with custom-fit shoulder straps and hipbelt. Features waterproof materials and reinforced high-wear points.	Hiking and Camp	Osprey	images/Aether Pro 70.png	4.7	\N
9	Endorphin Speed 3	Unisex performance running shoe with PWRRUN PB cushioning and nylon plate. Ideal for tempo runs and race day.	Running	Saucony	images/Endorphin Speed 3.png	4.8	\N
10	Copper Spur HV UL2	Ultralight 2-person tent with dual vestibules, steep wall architecture, and solution-dyed fabric for UV protection. 3-season design.	Hiking and Camp	Big Agnes	images/Copper Spur HV UL2.png	4.6	\N
11	Ultraboost 22	Premium running shoes featuring BOOST midsole technology, Primeknit+ upper, and Continental™ rubber outsole. Responsive cushioning for urban running.	Running	Adidas	images/Ultraboost 22.png	4.7	\N
12	Jetboil Flash	Compact camping stove system with 1L FluxRing cooking cup, push-button igniter, and color-change heat indicator. Boils water in 100 seconds.	Hiking and Camp	Jetboil	images/Jetboil Flash.png	4.8	\N
13	Clifton 9	Lightweight road running shoe with balanced cushioning, breathable engineered mesh upper, and early stage Meta-Rocker. Great for daily training.	Running	Hoka	images/Clifton 9.png	4.7	\N
14	Half Dome SL 2+	Spacious 2+ person tent with DAC Pressfit poles, fully seam-taped construction, and high-low ventilation. Easy setup with color-coded clips.	Hiking and Camp	The North Face	images/Half Dome SL 2+.png	4.5	\N
15	Glycerin 20	Premium neutral running shoe with DNA LOFT v3 cushioning and OrthoLite sock liner. Plush comfort for long-distance running.	Running	Brooks	images/Glycerin 20.png	4.8	\N
17	Bondi 8	Maximum cushioned road running shoe with Meta-Rocker geometry and memory foam collar. Ideal for recovery runs and long distances.	Running	Hoka	images/Bondi 8.png	4.6	\N
18	Flash Air 2	Ultralight semi-freestanding tent with dual doors, packable design, and seam-sealed construction. Weighs only 2 lbs 8 oz.	Hiking and Camp	REI	images/Flash Air 2.png	4.5	\N
19	Triumph 20	Premium neutral trainer with PWRRUN+ cushioning and FORMFIT technology. Engineered mesh upper provides adaptive fit.	Running	Saucony	images/Triumph 20.png	4.7	\N
20	Aether Plus 70	Extended size range backpack with custom fit components and reinforced carry system. Ideal for heavy loads.	Hiking and Camp	Osprey	images/Aether Plus 70.png	4.8	\N
21	Nimbus 25	Flagship cushioned running shoe with FF BLAST+ foam and TRUSSTIC stability system. Premium comfort for daily training.	Running	ASICS	images/Nimbus 25.png	4.7	\N
22	Dagger 2P	Lightweight backpacking tent with TrueTrack pole system and oversized vestibules. Quick setup in adverse conditions.	Hiking and Camp	NEMO	images/Dagger 2P.png	4.6	\N
23	Fresh Foam 1080v12	Premium neutral runner with Fresh Foam X midsole and engineered knit upper. Plush cushioning for long runs.	Running	New Balance	images/Fresh Foam 1080v12.png	4.7	\N
24	WindBurner Duo	Two-person integrated stove system with radiant burner and pressure regulator. Efficient performance in wind.	Hiking and Camp	MSR	images/WindBurner Duo.png	4.8	\N
25	Ride 16	Versatile neutral trainer with PWRRUN cushioning and updated mesh upper. Balanced ride for everyday running.	Running	Saucony	images/Ride 16.png	4.6	\N
26	Baltoro 75	Expedition-ready pack with Response A3 suspension and weatherproof construction. Built for serious adventures.	Hiking and Camp	Gregory	images/Baltoro 75.png	4.8	\N
27	Mach 5	Performance trainer with PROFLY+ midsole and engineered mesh upper. Responsive feel for tempo runs.	Running	Hoka	images/Mach 5.png	4.7	\N
29	Wave Rider 26	Signature neutral trainer with Mizuno Wave technology and Enerzy foam. Reliable cushioning for daily miles.	Running	Mizuno	images/Wave Rider 26.png	4.6	\N
30	Xenith 75	Technical backpack with custom molded hipbelt and advanced load transfer. Built for extended expeditions.	Hiking and Camp	Osprey	images/Xenith 75.png	4.9	\N
31	Rebel v3	Lightweight performance trainer with FuelCell foam and engineered mesh upper. Fast feel for uptempo running.	Running	New Balance	images/Rebel v3.png	4.7	\N
32	Tungsten 2P	Value-oriented backpacking tent with Zone pre-bend construction and color-coded setup. Durable design.	Hiking and Camp	Marmot	images/Tungsten 2P.png	4.5	\N
33	Novablast 3	Dynamic neutral trainer with FF BLAST+ cushioning and engineered mesh upper. Bouncy ride for daily training.	Running	ASICS	images/Novablast 3.png	4.7	\N
34	Flash 55	Lightweight pack with packmod compression and ventilated back panel. Versatile option for weekend trips.	Hiking and Camp	REI	images/Flash 55.png	4.6	\N
36	Deva 70	Women's specific expedition pack with Response Pro suspension and weatherproof construction. Built tough.	Hiking and Camp	Gregory	images/Deva 70.png	4.7	\N
38	Quarter Dome SL 2	Ultralight backpacking tent with DAC poles and minimal setup time. Optimized for weight savings.	Hiking and Camp	REI	images/Quarter Dome SL 2.png	4.7	\N
39	Kayano 29	Premium stability shoe with Dynamic DuoMax support and FF BLAST+ cushioning. Reliable support for overpronators.	Running	ASICS	images/Kayano 29.png	4.8	\N
40	Levitate 6	Neutral trainer with DNA AMP cushioning and updated fit knit upper. Energized feel for daily running.	Running	Brooks	images/Levitate 6.png	4.6	\N
42	Sense Ride 4	Versatile trail runner with Optivibe cushioning and Contagrip outsole. Comfortable on varied terrain.	Running	Salomon	images/Sense Ride 4.png	4.6	\N
43	Blaze 60	Technical pack with adjustable torso length and custom fit components. Ideal for weekend warriors.	Hiking and Camp	Granite Gear	images/Blaze 60.png	4.7	\N
44	Rincon 3	Lightweight neutral trainer with early-stage Meta-Rocker and compression-molded EVA. Fast feel for tempo days.	Running	Hoka	images/Rincon 3.png	4.5	\N
45	Tiger Wall UL2	Ultralight semi-freestanding tent with solution-dyed fabric and minimal pole design. Three-season protection.	Hiking and Camp	Big Agnes	images/Tiger Wall UL2.png	4.8	\N
46	Guide 15	Stability trainer with PWRRUN cushioning and structured mesh upper. Reliable support for daily miles.	Running	Saucony	images/Guide 15.png	4.6	\N
47	Crown2 60	Ultralight pack with removable frame and roll-top closure. Versatile option for thru-hiking.	Hiking and Camp	Granite Gear	images/Crown2 60.png	4.7	\N
48	Caldera 6	Maximum cushioned trail runner with balanced geometry and breathable upper. Comfortable on long runs.	Running	Brooks	images/Caldera 6.png	4.7	\N
50	Tempo Next%	Elite racing shoe with ZoomX foam and carbon fiber plate. Built for maximum speed on race day.	Running	Nike	images/Tempo Next%.png	4.9	\N
51	Aeon Li	Ultralight single-wall tent with Dyneema Composite construction. Minimalist shelter for serious adventurers.	Hiking and Camp	Tarptent	images/Aeon Li.png	4.6	\N
52	Cloudflow	Lightweight performance trainer with Helion superfoam and engineered mesh. Responsive feel for fast running.	Running	On	images/Cloudflow.png	4.7	\N
53	Zpacks Duplex	Two-person ultralight tent with Dyneema Composite Fabric. Minimalist design for thru-hiking.	Hiking and Camp	Zpacks	images/Zpacks Duplex.png	4.8	\N
54	Vaporfly Next% 2	Elite racing shoe with ZoomX foam and full-length carbon plate. Built for marathon performance.	Running	Nike	images/Vaporfly Next% 2.png	4.9	\N
55	Levity 45	Ultralight pack with AirSpeed suspension and NanoFly materials. Minimal weight without compromise.	Hiking and Camp	Osprey	images/Levity 45.png	4.7	\N
56	Speedgoat 5 GTX	Waterproof trail runner with Vibram Megagrip and GORE-TEX membrane. All-weather mountain running.	Running	Hoka	images/Speedgoat 5 GTX.png	4.8	\N
58	Endorphin Pro 3	Carbon-plated racing shoe with PWRRUN PB foam and lightweight upper. Built for speed.	Running	Saucony	images/Endorphin Pro 3.png	4.8	\N
59	Circuit 50	Entry-level backpack with adjustable torso and integrated rain cover. Great first backpacking pack.	Hiking and Camp	REI	images/Circuit 50.png	4.5	\N
60	Cloudultra	Trail running shoe with Helion superfoam and MissionGrip outsole. Built for ultra distances.	Running	On	images/Cloudultra.png	4.7	\N
61	Dagger 3P	Three-person backpacking tent with large vestibules and interior storage. Comfortable group shelter.	Hiking and Camp	NEMO	images/Dagger 3P.png	4.6	\N
62	Rebel v3	Lightweight performance trainer with FuelCell foam and engineered mesh. Fast and responsive.	Running	New Balance	images/Rebel v3.png	4.8	\N
63	Mariposa 60	Ultralight pack with removable frame and multiple external pockets. Popular among thru-hikers.	Hiking and Camp	Gossamer Gear	images/Mariposa 60.png	4.7	\N
64	Ultra Glide	Trail running shoe with Energy Surge foam and Contagrip MA outsole. Smooth ride on varied terrain.	Running	Salomon	images/Ultra Glide.png	4.6	\N
65	Lunar Solo	Single-wall ultralight tent with silnylon construction. Minimalist shelter for solo adventures.	Hiking and Camp	Six Moon Designs	images/Lunar Solo.png	4.5	\N
66	Clifton 9	Premium neutral trainer with balanced cushioning and engineered mesh upper. Perfect for daily training.	Running	Hoka	images/Clifton 9.png	4.7	\N
68	Glycerin 20	Plush neutral trainer with DNA LOFT v3 cushioning and stretch upper. Maximum comfort.	Running	Brooks	images/Glycerin 20.png	4.7	\N
69	Hubba Hubba NX	Two-person backpacking tent with symmetrical design and easy setup. Trail-tested reliability.	Hiking and Camp	MSR	images/Hubba Hubba NX.png	4.8	\N
70	Pegasus 40	Versatile neutral trainer with React foam and engineered mesh. Trusted daily trainer.	Running	Nike	images/Pegasus 40.png	4.6	\N
71	Crown3 60	Ultralight pack with optional frame and roll-top closure. Minimalist thru-hiking design.	Hiking and Camp	Granite Gear	images/Crown3 60.png	4.7	\N
72	Cloudmonster	Maximum cushioned road shoe with Helion superfoam. Plush ride for recovery runs.	Running	On	images/Cloudmonster.png	4.6	\N
1	Pegasus 40	Men's road running shoes with responsive cushioning, breathable mesh upper, and Nike React foam technology. Perfect for daily training runs.	Running	Nike	images/Pegasus 40.png	4.5	\N
6	MH2	2-person ultralight tent with double-wall construction, waterproof rainfly (3000mm), and aluminum poles. Easy 5-minute setup.	Hiking and Camp	Mountain Hardwear	images/MH2.png	4.4	\N
16	Tempest Pro 65	Women's specific 65L backpack with AirScape suspension, integrated rain cover, and trekking pole attachments. Perfect for extended backpacking trips.	Hiking and Camp	Osprey	images/Tempest Pro 65.png	4.7	\N
28	Dragonfly 2P	Ultralight double-wall tent with pre-bent poles and multiple ventilation options. Three-season protection.	Hiking and Camp	Big Agnes	images/Dragonfly 2P.png	4.5	\N
35	Speedcross 6	Aggressive trail runner with Contagrip outsole and QuickLace system. Superior grip on technical terrain.	Running	Salomon	images/Speedcross 6.png	4.8	\N
41	Hornet 2P	Ultralight tent with minimal pole structure and full coverage rainfly. Perfect for fast and light trips.	Hiking and Camp	NEMO	images/Hornet 2P.png	4.7	\N
49	Hubba Tour 2	Four-season tent with extended vestibule and robust weather protection. Built for harsh conditions.	Hiking and Camp	MSR	images/Hubba Tour 2.png	4.8	\N
57	Copper Spur HV UL3	Three-person ultralight tent with steep walls and multiple vestibules. Spacious lightweight shelter.	Hiking and Camp	Big Agnes	images/Copper Spur HV UL3.png	4.7	\N
67	Atmos AG 65	Premium backpack with Anti-Gravity suspension and integrated raincover. Excellent ventilation.	Hiking and Camp	Osprey	images/Atmos AG 65.png	4.8	\N
73	Exos 58	Ultralight backpack with AirSpeed suspension and stripped-down design. Fast and light trips.	Hiking and Camp	Osprey	images/Exos 58.png	4.7	\N
74	Magic Speed 2	Carbon-infused performance trainer with FF BLAST+ foam. Versatile speed shoe.	Running	ASICS	images/Magic Speed 2.png	4.7	\N
75	Paragon 58	Adjustable fit backpack with FreeFloat suspension. Versatile weekend pack.	Hiking and Camp	Gregory	images/Paragon 58.png	4.6	\N
76	Fresh Foam X 880v13	Reliable neutral trainer with Fresh Foam X cushioning. Consistent daily performer.	Running	New Balance	images/Fresh Foam X 880v13.png	4.7	\N
77	Copper Spur HV UL2	Two-person ultralight tent with high volume design. Popular backpacking choice.	Hiking and Camp	Big Agnes	images/Copper Spur HV UL2.png	4.8	\N
78	Triumph 21	Premium neutral trainer with PWRRUN+ cushioning. Luxurious daily running shoe.	Running	Saucony	images/Triumph 21.png	4.7	\N
79	Flash 45	Lightweight pack with adjustable torso and ventilated back panel. Weekend adventures.	Hiking and Camp	REI	images/Flash 45.png	4.6	\N
80	Wave Sky 6	Premium neutral trainer with Mizuno Enerzy foam. Plush cushioning for long runs.	Running	Mizuno	images/Wave Sky 6.png	4.7	\N
81	Aether 65	Technical backpack with custom fit components and integrated raincover. Extended trips.	Hiking and Camp	Osprey	images/Aether 65.png	4.8	\N
82	Cloudgo	Entry-level performance shoe with Helion foam. Versatile daily trainer.	Running	On	images/Cloudgo.png	4.6	\N
83	Blaze 60	Technical pack with adjustable torso and custom hip belt. Weekend warrior favorite.	Hiking and Camp	Granite Gear	images/Blaze 60.png	4.7	\N
84	Gel-Cumulus 25	Neutral trainer with FF BLAST cushioning. Reliable daily running shoe.	Running	ASICS	images/Gel-Cumulus 25.png	4.6	\N
85	Baltoro 65	Premium backpack with Response A3 suspension. Built for serious adventures.	Hiking and Camp	Gregory	images/Baltoro 65.png	4.8	\N
86	More v5	Maximum cushioned trainer with Fresh Foam X. Perfect for recovery runs.	Running	New Balance	images/More v5.png	4.7	\N
88	Endorphin Speed 3	Performance trainer with PWRRUN PB foam. Versatile speed day shoe.	Running	Saucony	images/Endorphin Speed 3.png	4.8	\N
89	Levity 60	Ultralight pack with AirSpeed suspension. Minimal weight for maximum distance.	Hiking and Camp	Osprey	images/Levity 60.png	4.7	\N
90	Ultra 3	Trail running shoe with updated cushioning. Built for ultra distances.	Running	The North Face	images/Ultra 3.png	4.6	\N
91	Tiger Wall UL3	Three-person ultralight tent with minimal pole design. Group backpacking shelter.	Hiking and Camp	Big Agnes	images/Tiger Wall UL3.png	4.7	\N
92	Hyperion Max	Carbon-infused trainer with DNA Flash foam. Speed day performance.	Running	Brooks	images/Hyperion Max.png	4.8	\N
93	Crown2 38	Ultralight pack with frameless design. Perfect for minimalist adventures.	Hiking and Camp	Granite Gear	images/Crown2 38.png	4.6	\N
94	Tempus	Stability shoe with PWRRUN PB foam. Support without compromise.	Running	Saucony	images/Tempus.png	4.7	\N
96	Cloudrunner	Protective neutral trainer with Helion foam. Reliable daily miles.	Running	On	images/Cloudrunner.png	4.6	\N
97	Ohm 2.0	Ultralight pack with removable frame. Minimalist thru-hiking design.	Hiking and Camp	ULA	images/Ohm 2.0.png	4.7	\N
98	Wave Inspire 19	Stability trainer with Mizuno Wave technology. Supportive daily runner.	Running	Mizuno	images/Wave Inspire 19.png	4.6	\N
99	Catalyst 2P	Two-person tent with trussed pole system. Spacious backpacking shelter.	Hiking and Camp	NEMO	images/Catalyst 2P.png	4.7	\N
100	Metaspeed Sky+	Carbon-plated racing shoe with FF TURBO foam. Elite marathon performance.	Running	ASICS	images/Metaspeed Sky+.png	4.9	\N
87	Dagger OSMO 2P	Two-person tent with OSMO waterproof fabric. Advanced weather protection.	Hiking and Camp	NEMO	images/Dagger OSMO 2P.png	4.8	\N
95	Zpacks Arc Blast	Ultralight pack with curved frame system. Thru-hiking favorite.	Hiking and Camp	Zpacks	images/Zpacks Arc Blast.png	4.8	\N
\.


--
-- Data for Name: products_variants; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products_variants (variant_id, product_id, size, color, price) FROM stdin;
1	1	40	Black/White	129.99
2	1	41	Black/White	129.99
3	1	42	Black/White	129.99
4	1	43	Black/White	129.99
5	1	44	Black/White	129.99
6	1	40	Blue/Orange	129.99
7	1	41	Blue/Orange	129.99
8	1	42	Blue/Orange	129.99
9	1	43	Blue/Orange	129.99
10	1	44	Blue/Orange	129.99
11	2	37	Purple/White	139.99
12	2	38	Purple/White	139.99
13	2	39	Purple/White	139.99
14	2	40	Purple/White	139.99
15	2	41	Purple/White	139.99
16	2	37	Black/Pink	139.99
17	2	38	Black/Pink	139.99
18	2	39	Black/Pink	139.99
19	2	40	Black/Pink	139.99
20	2	41	Black/Pink	139.99
21	3	40	Blue/Yellow	169.99
22	3	41	Blue/Yellow	169.99
23	3	42	Blue/Yellow	169.99
24	3	43	Blue/Yellow	169.99
25	3	44	Blue/Yellow	169.99
26	4	S	Blue	89.99
27	4	M	Blue	89.99
28	4	L	Blue	89.99
29	4	S	Green	89.99
30	4	M	Green	89.99
31	4	L	Green	89.99
32	5	S	Black	279.99
33	5	M	Black	279.99
34	5	L	Black	279.99
35	5	S	Blue	279.99
36	5	M	Blue	279.99
37	5	L	Blue	279.99
38	6	One Size	Orange	349.99
39	6	One Size	Green	349.99
40	7	One Size	Red	379.99
41	7	One Size	Grey	379.99
42	8	S	Black	289.99
43	8	M	Black	289.99
44	8	L	Black	289.99
45	9	40	White/Red	159.99
46	9	41	White/Red	159.99
47	9	42	White/Red	159.99
48	9	43	White/Red	159.99
49	9	44	White/Red	159.99
50	10	One Size	Orange	399.99
51	10	One Size	Green	399.99
52	11	40	Black/White	179.99
53	11	41	Black/White	179.99
54	11	42	Black/White	179.99
55	11	43	Black/White	179.99
56	11	44	Black/White	179.99
57	12	One Size	Red	129.99
58	12	One Size	Black	129.99
59	13	40	Blue/White	159.99
60	13	41	Blue/White	159.99
61	13	42	Blue/White	159.99
62	13	43	Blue/White	159.99
63	13	44	Blue/White	159.99
64	14	One Size	Yellow	299.99
65	14	One Size	Green	299.99
66	15	40	Grey/Blue	169.99
67	15	41	Grey/Blue	169.99
68	15	42	Grey/Blue	169.99
69	15	43	Grey/Blue	169.99
70	15	44	Grey/Blue	169.99
71	16	S	Purple	259.99
72	16	M	Purple	259.99
73	16	L	Purple	259.99
74	17	40	White/Blue	169.99
75	17	41	White/Blue	169.99
76	17	42	White/Blue	169.99
77	17	43	White/Blue	169.99
78	17	44	White/Blue	169.99
79	18	One Size	Green	299.99
80	18	One Size	Grey	299.99
81	19	40	Blue/White	159.99
82	19	41	Blue/White	159.99
83	19	42	Blue/White	159.99
84	19	43	Blue/White	159.99
85	19	44	Blue/White	159.99
86	20	S	Black	299.99
87	20	M	Black	299.99
88	20	L	Black	299.99
89	21	40	Black/Gold	169.99
90	21	41	Black/Gold	169.99
91	21	42	Black/Gold	169.99
92	21	43	Black/Gold	169.99
93	21	44	Black/Gold	169.99
94	22	One Size	Orange	449.99
95	22	One Size	Blue	449.99
96	23	40	Grey/Blue	179.99
97	23	41	Grey/Blue	179.99
98	23	42	Grey/Blue	179.99
99	23	43	Grey/Blue	179.99
100	23	44	Grey/Blue	179.99
101	24	S	Red	289.99
102	24	M	Red	289.99
103	24	L	Red	289.99
104	25	40	White/Green	159.99
105	25	41	White/Green	159.99
106	25	42	White/Green	159.99
107	25	43	White/Green	159.99
108	25	44	White/Green	159.99
109	26	One Size	Black	349.99
110	26	One Size	Navy	349.99
111	27	40	Grey/Orange	169.99
112	27	41	Grey/Orange	169.99
113	27	42	Grey/Orange	169.99
114	27	43	Grey/Orange	169.99
115	27	44	Grey/Orange	169.99
116	28	S	Blue	279.99
117	28	M	Blue	279.99
118	28	L	Blue	279.99
119	29	40	Black/Red	189.99
120	29	41	Black/Red	189.99
121	29	42	Black/Red	189.99
122	29	43	Black/Red	189.99
123	29	44	Black/Red	189.99
124	30	One Size	Green	399.99
125	30	One Size	Brown	399.99
126	31	S	Grey	269.99
127	31	M	Grey	269.99
128	31	L	Grey	269.99
129	32	40	Blue/Black	179.99
130	32	41	Blue/Black	179.99
131	32	42	Blue/Black	179.99
132	32	43	Blue/Black	179.99
133	32	44	Blue/Black	179.99
134	33	One Size	Red	329.99
135	33	One Size	White	329.99
136	34	40	Black/Blue	169.99
137	34	41	Black/Blue	169.99
138	34	42	Black/Blue	169.99
139	34	43	Black/Blue	169.99
140	34	44	Black/Blue	169.99
141	35	S	Purple	289.99
142	35	M	Purple	289.99
143	35	L	Purple	289.99
144	36	40	White/Red	159.99
145	36	41	White/Red	159.99
146	36	42	White/Red	159.99
147	36	43	White/Red	159.99
148	36	44	White/Red	159.99
149	37	One Size	Blue	379.99
150	37	One Size	Black	379.99
151	38	S	Orange	299.99
152	38	M	Orange	299.99
153	38	L	Orange	299.99
154	39	40	Grey/White	169.99
155	39	41	Grey/White	169.99
156	39	42	Grey/White	169.99
157	39	43	Grey/White	169.99
158	39	44	Grey/White	169.99
159	40	One Size	Green	419.99
160	40	One Size	Yellow	419.99
161	41	S	Navy	279.99
162	41	M	Navy	279.99
163	41	L	Navy	279.99
164	42	40	Red/Black	189.99
165	42	41	Red/Black	189.99
166	42	42	Red/Black	189.99
167	42	43	Red/Black	189.99
168	42	44	Red/Black	189.99
169	43	One Size	Purple	359.99
170	43	One Size	Grey	359.99
171	44	40	White/Black	169.99
172	44	41	White/Black	169.99
173	44	42	White/Black	169.99
174	44	43	White/Black	169.99
175	44	44	White/Black	169.99
176	45	S	Green	289.99
177	45	M	Green	289.99
178	45	L	Green	289.99
179	46	40	Blue/Grey	179.99
180	46	41	Blue/Grey	179.99
181	46	42	Blue/Grey	179.99
182	46	43	Blue/Grey	179.99
183	46	44	Blue/Grey	179.99
184	47	One Size	Red	399.99
185	47	One Size	Black	399.99
186	48	S	Yellow	269.99
187	48	M	Yellow	269.99
188	48	L	Yellow	269.99
189	49	40	Black/Green	169.99
190	49	41	Black/Green	169.99
191	49	42	Black/Green	169.99
192	49	43	Black/Green	169.99
193	49	44	Black/Green	169.99
194	50	One Size	Blue	429.99
195	50	One Size	Orange	429.99
196	51	S	Black	259.99
197	51	M	Black	259.99
198	51	L	Black	259.99
199	52	40	White/Blue	179.99
200	52	41	White/Blue	179.99
201	52	42	White/Blue	179.99
202	52	43	White/Blue	179.99
203	52	44	White/Blue	179.99
204	53	One Size	Red	389.99
205	53	One Size	Grey	389.99
206	54	S	Purple	279.99
207	54	M	Purple	279.99
208	54	L	Purple	279.99
209	55	40	Black/White	169.99
210	55	41	Black/White	169.99
211	55	42	Black/White	169.99
212	55	43	Black/White	169.99
213	55	44	Black/White	169.99
214	56	One Size	Green	409.99
215	56	One Size	Blue	409.99
216	57	S	Orange	289.99
217	57	M	Orange	289.99
218	57	L	Orange	289.99
219	58	40	Grey/Black	179.99
220	58	41	Grey/Black	179.99
221	58	42	Grey/Black	179.99
222	58	43	Grey/Black	179.99
223	58	44	Grey/Black	179.99
224	59	One Size	Yellow	379.99
225	59	One Size	Purple	379.99
226	60	S	Red	269.99
227	60	M	Red	269.99
228	60	L	Red	269.99
229	61	40	Blue/White	189.99
230	61	41	Blue/White	189.99
231	61	42	Blue/White	189.99
232	61	43	Blue/White	189.99
233	61	44	Blue/White	189.99
234	62	One Size	Black	419.99
235	62	One Size	Grey	419.99
236	63	S	Green	299.99
237	63	M	Green	299.99
238	63	L	Green	299.99
239	64	40	Red/Grey	169.99
240	64	41	Red/Grey	169.99
241	64	42	Red/Grey	169.99
242	64	43	Red/Grey	169.99
243	64	44	Red/Grey	169.99
244	65	One Size	Orange	399.99
245	65	One Size	Blue	399.99
246	66	S	Yellow	279.99
247	66	M	Yellow	279.99
248	66	L	Yellow	279.99
249	67	40	Purple/Black	179.99
250	67	41	Purple/Black	179.99
251	67	42	Purple/Black	179.99
252	67	43	Purple/Black	179.99
253	67	44	Purple/Black	179.99
254	68	One Size	White	429.99
255	68	One Size	Red	429.99
256	69	S	Grey	269.99
257	69	M	Grey	269.99
258	69	L	Grey	269.99
259	70	40	Green/Blue	189.99
260	70	41	Green/Blue	189.99
261	70	42	Green/Blue	189.99
262	70	43	Green/Blue	189.99
263	70	44	Green/Blue	189.99
264	71	S	Black	289.99
265	71	M	Black	289.99
266	71	L	Black	289.99
267	72	40	White/Blue	169.99
268	72	41	White/Blue	169.99
269	72	42	White/Blue	169.99
270	72	43	White/Blue	169.99
271	72	44	White/Blue	169.99
272	73	S	Red	279.99
273	73	M	Red	279.99
274	73	L	Red	279.99
275	74	40	Blue/Black	179.99
276	74	41	Blue/Black	179.99
277	74	42	Blue/Black	179.99
278	74	43	Blue/Black	179.99
279	74	44	Blue/Black	179.99
280	75	S	Green	269.99
281	75	M	Green	269.99
282	75	L	Green	269.99
283	76	40	Grey/White	169.99
284	76	41	Grey/White	169.99
285	76	42	Grey/White	169.99
286	76	43	Grey/White	169.99
287	76	44	Grey/White	169.99
288	77	S	Orange	289.99
289	77	M	Orange	289.99
290	77	L	Orange	289.99
291	78	40	Black/Red	179.99
292	78	41	Black/Red	179.99
293	78	42	Black/Red	179.99
294	78	43	Black/Red	179.99
295	78	44	Black/Red	179.99
296	79	S	Blue	259.99
297	79	M	Blue	259.99
298	79	L	Blue	259.99
299	80	40	White/Green	169.99
300	80	41	White/Green	169.99
301	80	42	White/Green	169.99
302	80	43	White/Green	169.99
303	80	44	White/Green	169.99
304	81	S	Black	299.99
305	81	M	Black	299.99
306	81	L	Black	299.99
307	82	40	Blue/Orange	169.99
308	82	41	Blue/Orange	169.99
309	82	42	Blue/Orange	169.99
310	82	43	Blue/Orange	169.99
311	82	44	Blue/Orange	169.99
312	83	S	Grey	279.99
313	83	M	Grey	279.99
314	83	L	Grey	279.99
315	84	40	Black/White	169.99
316	84	41	Black/White	169.99
317	84	42	Black/White	169.99
318	84	43	Black/White	169.99
319	84	44	Black/White	169.99
320	85	S	Blue	299.99
321	85	M	Blue	299.99
322	85	L	Blue	299.99
323	86	40	Red/Black	179.99
324	86	41	Red/Black	179.99
325	86	42	Red/Black	179.99
326	86	43	Red/Black	179.99
327	86	44	Red/Black	179.99
328	87	S	Orange	289.99
329	87	M	Orange	289.99
330	87	L	Orange	289.99
331	88	40	Blue/White	179.99
332	88	41	Blue/White	179.99
333	88	42	Blue/White	179.99
334	88	43	Blue/White	179.99
335	88	44	Blue/White	179.99
336	89	S	Black	269.99
337	89	M	Black	269.99
338	89	L	Black	269.99
339	90	40	Grey/Red	169.99
340	90	41	Grey/Red	169.99
341	90	42	Grey/Red	169.99
342	90	43	Grey/Red	169.99
343	90	44	Grey/Red	169.99
344	91	S	Green	289.99
345	91	M	Green	289.99
346	91	L	Green	289.99
347	92	40	Black/Gold	179.99
348	92	41	Black/Gold	179.99
349	92	42	Black/Gold	179.99
350	92	43	Black/Gold	179.99
351	92	44	Black/Gold	179.99
352	93	S	Blue	259.99
353	93	M	Blue	259.99
354	93	L	Blue	259.99
355	94	One Size	Orange	449.99
356	94	One Size	Blue	449.99
357	95	S	Black	299.99
358	95	M	Black	299.99
359	95	L	Black	299.99
360	96	40	White/Blue	169.99
361	96	41	White/Blue	169.99
362	96	42	White/Blue	169.99
363	96	43	White/Blue	169.99
364	96	44	White/Blue	169.99
365	97	S	Grey	279.99
366	97	M	Grey	279.99
367	97	L	Grey	279.99
368	98	40	Black/Red	179.99
369	98	41	Black/Red	179.99
370	98	42	Black/Red	179.99
371	98	43	Black/Red	179.99
372	98	44	Black/Red	179.99
373	99	S	Orange	269.99
374	99	M	Orange	269.99
375	99	L	Orange	269.99
376	100	40	Blue/Gold	189.99
377	100	41	Blue/Gold	189.99
378	100	42	Blue/Gold	189.99
379	100	43	Blue/Gold	189.99
380	100	44	Blue/Gold	189.99
\.


--
-- Data for Name: shopping_list_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shopping_list_items (item_id, list_id, product_id, variant_id, quantity) FROM stdin;
\.


--
-- Data for Name: shopping_lists; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.shopping_lists (list_id, user_id) FROM stdin;
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: stores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stores (store_id, name, address, city, postal_code, country, popularity_score, location) FROM stdin;
1	Sports Gran Via 2	Avinguda de la Granvia de Hospitalet 75	Barcelona	08908	Spain	4.3	0101000020E61000001AD01CA386B044407AB0202812070140
2	Sports L'illa Diagonal	Avinguda Diagonal 577	Barcelona	 08029	 Spain	4.5	0101000020E610000085D272FB40B1444018AB7246390D0140
3	Sports Ciutat Vella	Carrer de la Canuda 20	Barcelona	08002	Spain	4.3	0101000020E610000062759ABB4CB144402837401F1B370140
4	Sports Gracia	Carrer Gran de Gracia 54	Barcelona	08012	Spain	4.1	0101000020E6100000AD6301B8FEB04440EA888DC3AAFB0040
5	Sports Diagonal Mar	Avinguda Diagonal 3	Barcelona	08012	Spain	4.6	0101000020E6100000610B8B9B64B344409411BCC6D3970140
6	Sports La Maquinista	Carrer de Potosi 2	Barcelona	08030	Spain	4.5	0101000020E6100000E0AEA8D260B64440CDCF68064C8B0140
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, first_name, last_name, address, city, postal_code, location, email) FROM stdin;
1	Alicia	Dubo	Carrer del Rec 71	 Barcelona	 08003	0101000020E610000012842BA050B14440BB809719364A0140	\N
2	Bob	Martin	Carrer de la Font 12	 Barcelona	 08014	0101000020E61000002B8A5759DBB0444038F7578FFB160140	\N
3	Joan	Casado	Carrer de la Mare 10	 Barcelona	 08028	0101000020E61000000C1F115322B34440AE8383BD89410140	\N
4	Clara	Ruiz	Carrer de relotge 1	 Barcelona	 08023	0101000020E6100000FA08FCE1E7B34440CC988235CE660140	\N
5	Miguel	Tuscany	Carrer Muntaner 39	Barcelona	 08011	0101000020E61000008AAE0B3F38B144401FBB0B9414780140	\N
\.


--
-- Name: delivery_methods_delivery_method_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.delivery_methods_delivery_method_id_seq', 1, false);


--
-- Name: inventory_inventory_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inventory_inventory_id_seq', 1, false);


--
-- Name: order_items_order_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.order_items_order_item_id_seq', 5, true);


--
-- Name: orders_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_order_id_seq', 5, true);


--
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_product_id_seq', 1, false);


--
-- Name: products_variants_variant_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_variants_variant_id_seq', 1, false);


--
-- Name: shopping_list_items_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shopping_list_items_item_id_seq', 42, true);


--
-- Name: shopping_lists_list_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.shopping_lists_list_id_seq', 39, true);


--
-- Name: stores_store_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stores_store_id_seq', 1, false);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 1, false);


--
-- Name: delivery_methods delivery_methods_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_methods
    ADD CONSTRAINT delivery_methods_pkey PRIMARY KEY (delivery_method_id);


--
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_item_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: products_variants products_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products_variants
    ADD CONSTRAINT products_variants_pkey PRIMARY KEY (variant_id);


--
-- Name: shopping_list_items shopping_list_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_list_items
    ADD CONSTRAINT shopping_list_items_pkey PRIMARY KEY (item_id);


--
-- Name: shopping_lists shopping_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_lists
    ADD CONSTRAINT shopping_lists_pkey PRIMARY KEY (list_id);


--
-- Name: stores stores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stores
    ADD CONSTRAINT stores_pkey PRIMARY KEY (store_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: idx_inventory_store_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_inventory_store_id ON public.inventory USING btree (store_id);


--
-- Name: idx_inventory_variant_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_inventory_variant_id ON public.inventory USING btree (variant_id);


--
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_variant_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_order_items_variant_id ON public.order_items USING btree (variant_id);


--
-- Name: idx_orders_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_status ON public.orders USING btree (order_status);


--
-- Name: idx_orders_store_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_store_id ON public.orders USING btree (store_id);


--
-- Name: idx_orders_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_user_id ON public.orders USING btree (user_id);


--
-- Name: idx_products_brand; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_brand ON public.products USING btree (brand);


--
-- Name: idx_products_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_category ON public.products USING btree (category);


--
-- Name: idx_products_embedding_scann; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_embedding_hnsw ON public.products USING hnsw (embedding public.vector_cosine_ops);


--
-- Name: idx_products_search_vector; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_search_vector ON public.products USING gin (search_vector);


--
-- Name: idx_stores_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_stores_location ON public.stores USING gist (location);


--
-- Name: idx_users_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_location ON public.users USING gist (location);


--
-- Name: idx_variants_product_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_variants_product_id ON public.products_variants USING btree (product_id);


--
-- Name: delivery_methods delivery_methods_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.delivery_methods
    ADD CONSTRAINT delivery_methods_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id);


--
-- Name: inventory inventory_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id) ON DELETE CASCADE;


--
-- Name: inventory inventory_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory
    ADD CONSTRAINT inventory_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.products_variants(variant_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(order_id) ON DELETE CASCADE;


--
-- Name: order_items order_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.products_variants(variant_id);


--
-- Name: orders orders_delivery_method_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_delivery_method_id_fkey FOREIGN KEY (delivery_method_id) REFERENCES public.delivery_methods(delivery_method_id);


--
-- Name: orders orders_store_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_store_id_fkey FOREIGN KEY (store_id) REFERENCES public.stores(store_id);


--
-- Name: products_variants products_variants_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products_variants
    ADD CONSTRAINT products_variants_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id);


--
-- Name: shopping_list_items shopping_list_items_list_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_list_items
    ADD CONSTRAINT shopping_list_items_list_id_fkey FOREIGN KEY (list_id) REFERENCES public.shopping_lists(list_id) ON DELETE CASCADE;


--
-- Name: shopping_list_items shopping_list_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_list_items
    ADD CONSTRAINT shopping_list_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id) ON DELETE CASCADE;


--
-- Name: shopping_list_items shopping_list_items_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_list_items
    ADD CONSTRAINT shopping_list_items_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.products_variants(variant_id) ON DELETE CASCADE;


--
-- Name: shopping_lists shopping_lists_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.shopping_lists
    ADD CONSTRAINT shopping_lists_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: FUNCTION pg_replication_origin_advance(text, pg_lsn); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_create(text); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_drop(text); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_oid(text); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_progress(text, boolean); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_session_is_setup(); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_session_progress(boolean); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_session_reset(); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_session_setup(text); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_xact_reset(); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- Name: FUNCTION pg_show_replication_origin_status(OUT local_id oid, OUT external_id text, OUT remote_lsn pg_lsn, OUT local_lsn pg_lsn); Type: ACL; Schema: pg_catalog; Owner: alloydbadmin
--



--
-- PostgreSQL database dump complete
--

