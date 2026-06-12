"""Apply pre-computed English translations (with **bold** answer markup) to question JSON files."""
import json
from pathlib import Path

DATA = Path(__file__).parent / 'data'

# (level, qi): new translation string
TRANSLATIONS = {
    # ── N5 vocabulary fill-blank ──────────────────────────────────────────
    (5, 0):  "Please **turn off** the TV because it's loud.",
    (5, 2):  "Because I was thirsty, I **drank** water.",
    (5, 3):  "I **went** to the station by train.",
    (5, 4):  "I **read** this book at the library.",
    (5, 5):  "The teacher **wrote** letters on the blackboard.",
    (5, 6):  "Because I was hungry, I **ate** rice.",
    (5, 7):  "I **bought** new shoes at the store.",
    (5, 8):  "I **spoke** with my friend on the phone.",
    (5, 9):  "I study while **listening to** music.",
    (5, 10): "Please **close** the window. It's cold outside.",
    (5, 11): "Please **turn on** the lights because it's dark.",
    (5, 12): "Because work was over, I **went home**.",
    (5, 13): "I **go** to school every day.",
    (5, 14): "My friend **came** to my house.",
    (5, 15): "I **use** this bag every day.",
    (5, 16): "I **learn** Japanese from a teacher.",
    (5, 17): "I **teach** English to students.",
    (5, 18): "I **go to sleep** early at night.",
    (5, 19): "Please **come into** this room.",
    (5, 20): "I **watched** a movie yesterday.",
    (5, 21): "I **bought** vegetables at the supermarket.",
    (5, 22): "I **wrote** a letter to my friend.",
    (5, 23): "I go to school **after eating** breakfast.",
    (5, 25): "Because I had a headache, I **took** medicine.",
    (5, 26): "I **rest** at home in the afternoon.",
    (5, 27): "I **study** Japanese every day.",
    (5, 28): "I **leave** the office at 6 o'clock.",
    (5, 29): "The train **arrives** at the station.",
    (5, 30): "Because I have no money, I **won't buy** what I want.",
    (5, 31): "Because that restaurant is expensive, I **don't go** there often.",
    (5, 32): "Since your hands are dirty, **please wash** them.",
    (5, 33): "May I **use** this pen?",
    (5, 34): "I want to **speak** Japanese when I go to Japan.",
    (5, 35): "I **bought** eggs and meat at the supermarket.",
    (5, 36): "Tomorrow I will **watch** a movie with my mother.",
    (5, 37): "Yesterday I **stayed up** until midnight.",
    (5, 38): "The baby is **sleeping**.",
    (5, 39): "The flowers are **blooming**. How beautiful!",
    (5, 40): "Tanaka-san is **talking** on the phone right now.",
    (5, 41): "Since the weather is nice today, I want to **play** outside.",
    (5, 42): "May I **borrow** this dictionary?",
    (5, 44): "It has started **raining**. Let's bring an umbrella.",
    (5, 45): "I read the newspaper while **drinking** coffee.",
    (5, 46): "Please **open** this door. It's a parking lot.",
    (5, 47): "Please **take** a photo.",
    (5, 48): "Please **write** your name here.",
    (5, 49): "I **met** a friend in front of the school.",
    # ── N5 grammar fill-blank (particles) ───────────────────────────────
    (5, 50): "I go **to** school every day.",
    (5, 51): "This is **my** book.",
    (5, 52): "I take the train **at** the station.",
    (5, 53): "I read books **at** the library.",
    (5, 54): "**I** like Japanese.",
    (5, 55): "I watch a movie **with** a friend.",
    (5, 56): "I work **from** 9 to 5.",
    (5, 57): "I go from Tokyo **to** Osaka by Shinkansen.",
    (5, 58): "It would be nice **if** it's sunny tomorrow.",
    (5, 59): "Let's eat **after** washing our hands.",
    # ── N5 kanji reading ─────────────────────────────────────────────────
    (5, 92): "That mountain is very tall. The reading of '山' is **やま**.",
    (5, 93): "A child is playing in this river. The reading of '川' is **かわ**.",
    (5, 94): "The moon last night was beautiful. The reading of '月' is **つき**.",
    (5, 95): "That cat is white. The reading of '白' is **しろ**.",
    (5, 96): "Today I'm wearing red clothes. The reading of '赤' is **あか**.",
    (5, 97): "The sky is blue and beautiful. The reading of '青' is **あお**.",
    (5, 98): "There is a book on the desk. The reading of '上' is **うえ**.",
    (5, 99): "There is a cat under the chair. The reading of '下' is **した**.",
    # ── N5 kanji writing ─────────────────────────────────────────────────
    (5, 102): "There is a **mountain** near the house. (Which kanji is 'yama'?)",
    (5, 103): "I drink **water** every day. (Which kanji is 'mizu'?)",
    (5, 104): "The station is to the **north**. (Which kanji is 'kita'?)",
    (5, 105): "My family lives in the **south**. (Which kanji is 'minami'?)",
    (5, 106): "The **sky** is blue today. (Which kanji is 'sora'?)",
    (5, 107): "His **hands** are beautiful. (Which kanji is 'te'?)",
    (5, 108): "Father goes to work by **car**. (Which kanji is 'kuruma'?)",
    (5, 109): "Please get off at the bus stop in front of the **station**. (Which kanji is 'eki'?)",
    # ── N5 sentence reorder ──────────────────────────────────────────────
    (5, 110): "Tanaka-san is living **happily**.",
    (5, 111): "Every morning, I **get up** [at a set time].",
    (5, 112): "I caught the **bus** in front of the station.",
    (5, 113): "I **bought** things at the supermarket.",
    (5, 114): "Yesterday, I went somewhere **by train**.",
    # ── N4 vocabulary fill-blank ─────────────────────────────────────────
    (4, 46): "I heated up yesterday's curry in the **microwave** and ate it.",
    (4, 47): "I asked everyone in the class for their **opinions** about where to travel, and decided.",
    (4, 48): "The bed I bought last week **arrived** home today.",
    (4, 49): "It has **gone past** 12 o'clock, so let's take a lunch break.",
    (4, 50): "Since there are few people today, 10 pieces will be **enough**.",
    (4, 51): "When I was a child, I often fought with my brother and was **scolded** by my father.",
    (4, 52): "I bought a lot, so there is only 500 yen **remaining** in my wallet.",
    (4, 53): "I feed it, take it for walks, and take **care** of my dog every day.",
    (4, 54): "I **invited** my friend, and they came to the party.",
    (4, 55): "Because I didn't have **time** to eat breakfast, I was late for school.",
    (4, 56): "Please **take** this medicine after every meal.",
    (4, 57): "The phone is **ringing**, so please answer it.",
    (4, 58): "The luggage is too **heavy** for one person to carry.",
    (4, 59): "I **contacted** the teacher and consulted about the exam.",
    (4, 60): "It looks like it will **rain** tonight.",
    (4, 61): "Because I practice every day, I have been getting **gradually** better.",
    # ── N4 grammar fill-blank ────────────────────────────────────────────
    (4, 78): "I often travel **by** airplane for work.",
    (4, 79): "This morning, a package arrived **from** my mother in the countryside.",
    (4, 80): "(In the classroom) Teacher: 'Now, please introduce yourselves one **at a time**.'",
    (4, 81): 'Tanaka: "What, you eat it **as many as** 3 times a week? You must really love it."',
    (4, 82): "I study hard and want to go to a foreign university **someday**.",
    (4, 84): "Classes end at around **3 o'clock** every day.",
    (4, 85): "The cherry blossoms in the garden bloomed **earlier** than last year.",
    (4, 86): "I really hate bugs, and I find **even seeing** them unpleasant.",
    (4, 87): "The refrigerator **is making** a strange noise. It might be broken.",
    (4, 88): "In my grandmother's room, who loves flowers, various flowers are always **on display**.",
    (4, 89): 'Yamakawa: "Summer vacation is coming soon. Ann, are you going back this summer too?" Ann: "No. Since I\'ll be working part-time in Japan this year, I **decided not to go back**."',
    (4, 90): '(In the kitchen) Brother: "Sis, I\'ll help with something." Sister: "Thanks. Then, could you **cut** the tomatoes?" Brother: "Sure."',
    (4, 91): "**Even though** I study Japanese every day, I still can't speak much.",
    (4, 92): "**After** graduating, I started working.",
    (4, 93): "I understood the homework **after having the teacher** explain it to me.",
    (4, 94): "She can speak **not only** French **but also** Spanish.",
    (4, 95): "I cook **while** listening to music.",
    (4, 96): "I've watched this movie **as many as** 3 times.",
    (4, 97): "Starting from next week, school **will begin**.",
    # ── N4 sentence reorder ──────────────────────────────────────────────
    (4, 98):  "Today is the **longest** day of the year.",
    (4, 99):  "I want to take lots of photos while traveling to **various towns** in Japan.",
    (4, 100): "Apparently, I loved this picture book when I was little, so they tell me the **story**.",
    (4, 101): "Today, Kimura-san came wearing a blue shirt. I want the same shirt he was **wearing**.",
    (4, 102): "The child has become able to **walk**.",
    (4, 103): "She seems to be talking **on the phone**.",
    (4, 104): "Please eat this cake after **cutting** it.",
    (4, 105): "Tanaka-san talked about the **old days**.",
    # ── N3 vocabulary fill-blank ─────────────────────────────────────────
    (3, 28): "**Compared** to 50 years ago, the population of this town has increased by 100,000.",
    (3, 29): "I **applied** for a part-time job and started a new job last month.",
    (3, 31): "Construction is underway to widen the road in order to **solve** the traffic congestion problem.",
    (3, 32): "Let's observe good **manners** and be quiet on the train.",
    (3, 34): "Since his speech just now was truly wonderful, it's **certain** that he will win.",
    (3, 35): "Since the child is sleeping, I **gently** closed the door so as not to make noise.",
    (3, 36): "The **content** of this movie is complex, and no matter how many times you watch it, there are new discoveries.",
    (3, 37): "When planning the trip, I first gathered **information**.",
    (3, 38): "Taking the failure as a **lesson**, I thought I would do better next time.",
    (3, 39): "This store has a good **reputation** and is always full of customers.",
    (3, 40): "To live abroad, it is important to get used to the local **culture**.",
    (3, 41): "She always brightens up those around her with her **cheerful** smile.",
    (3, 42): "While **waiting** for the train on the station platform, I ran into a friend.",
    (3, 43): "In order to **improve** my work, I wake up early every day to study.",
    (3, 44): "During an earthquake, it is important to first ensure your personal **safety**.",
    (3, 45): "His story was full of **humor**, and everyone laughed.",
    (3, 46): "The number of young people working on environmental issues with genuine **interest** is increasing.",
    (3, 47): "Please state your **answer** to this problem.",
    (3, 48): "It took some time to **adapt** to the new workplace.",
    (3, 49): "Please take this medicine after meals **without fail**.",
    (3, 50): "He is a very **proactive** person who is kind to everyone.",
    (3, 51): "If you speak a little more **specifically**, I'll understand much better.",
    (3, 52): "Recently, work has been busy and I have little **breathing room**.",
    (3, 53): "By **distributing** posters, we called on everyone to participate in the event.",
    # ── N3 grammar fill-blank ────────────────────────────────────────────
    (3, 71): "**As** I got used to work, I became able to speak with customers with a smile.",
    (3, 72): "The rain that had been falling for three days **finally** stopped, and today we can see blue sky.",
    (3, 73): "Online shopping is **convenient, but on the other hand** there is also the fear of not being able to see the seller's face.",
    (3, 74): "Babies tend to **put** everything they grab into their mouths, so care must be taken not to place dangerous things nearby.",
    (3, 75): '"Hello, I\'m rushing your way right now, but it **looks like I won\'t make it** in time."',
    (3, 76): 'Since the pond near the elementary school is deep and dangerous, they put up a sign saying "**Do not enter** the pond!"',
    (3, 77): "When I find shoes online, I inevitably **end up buying** them.",
    (3, 78): "**Just today**, I saw the same cat twice, in the morning and evening.",
    (3, 79): "I went out **without bringing** an umbrella, but it suddenly started raining and I got wet.",
    (3, 80): "Studying for exams was tough, but things were even tougher **after I entered** university.",
    (3, 81): "In the evening, when I open the window, the smell of miso soup **comes wafting** in.",
    (3, 82): '(At the office) "I want to **get this work done** by the end of today."',
    (3, 83): "I think it's better to have children learn **things they are interested in**.",
    (3, 84): "She practiced every day. As a result, she was **finally** able to win the competition.",
    (3, 85): "**When making** plans for next year, I decided to first look back on this year.",
    (3, 86): "Since this document has complex content, care is needed **when** reading it.",
    (3, 87): "Sports are **not only** good for your health, but also help relieve stress.",
    (3, 88): "**If** you plan to watch this movie, it's better to reserve early.",
    (3, 89): "**By being** kind, he is always thanked by everyone.",
    (3, 90): "**Although** this work is difficult, it is rewarding.",
    (3, 91): "She seemed very **happy** to have received a present.",
    (3, 92): "**Even if** we are far apart, our friendship will not change.",
    (3, 93): "There is a **risk of** heavy rain from tomorrow afternoon into the evening.",
    # ── N3 sentence reorder ──────────────────────────────────────────────
    (3, 94):  "Restaurant A became a popular establishment where **reservations are hard to get**.",
    (3, 95):  "For children, I think it's better to have them learn their parents' **interests**.",
    (3, 96):  "Next month I'll compete in a speech contest. I plan to speak **without looking at notes**.",
    (3, 97):  "I want to swim **more skillfully**.",
    (3, 98):  "I watched this movie for the **first time** and was moved.",
    (3, 99):  "Yesterday I was truly nervous until the end about **which side would win**.",
    (3, 100): "Apparently I loved this picture book when I was little, so they tell me the **story**.",
    (3, 101): "Today at school, I want a shirt like the one someone was **wearing**.",
    (3, 102): "She has talent **even in dancing**.",
    (3, 103): "This problem cannot be solved easily **despite appearing** simple.",
    # ── N2 kanji reading ─────────────────────────────────────────────────
    (2, 0):  "This law was **implemented** (施行; read: **しこう**) last year.",
    (2, 1):  "She has **outstanding** (卓越; read: **たくえつ**) skills.",
    (2, 2):  "At this factory, the **disposal** (処理; read: **しょり**) of waste has become a problem.",
    (2, 3):  "I think his statement is **contradictory** (矛盾; read: **むじゅん**).",
    (2, 4):  "His **arrogant** (傲慢; read: **ごうまん**) attitude made people around him uncomfortable.",
    (2, 5):  "I went to the municipal office to get a **family register** (戸籍; read: **こせき**) certificate.",
    # ── N2 kanji writing ─────────────────────────────────────────────────
    (2, 6):  "This product has **multiple** (複数; read: ふくすう) problems.",
    (2, 7):  "The implementation of the plan was **postponed** (延期; read: えんき).",
    (2, 8):  "The government is aiming for economic **growth** (成長; read: せいちょう).",
    (2, 9):  "That remark has no **basis** (根拠; read: こんきょ).",
    (2, 10): "The company's performance **improved** (改善; read: かいぜん).",
    (2, 11): "She is studying **diligently** (勤勉; read: きんべん).",
    # ── N2 vocabulary fill-blank ─────────────────────────────────────────
    (2, 12): "As the **first step** of the new project, we first conducted market research.",
    (2, 13): "He **skillfully** avoided the difficult question.",
    (2, 14): "The movie made a deep **impression** on the audience.",
    (2, 15): "The project is progressing as **planned**.",
    (2, 16): "Expert opinions are necessary for the **resolution** of this problem.",
    (2, 17): "She is good at expressing her emotions **richly**.",
    (2, 18): "He showed **reluctance** toward the proposal.",
    (2, 19): "It is known that this medicine has **rare** side effects.",
    (2, 20): "He has **outstanding** talent for business.",
    (2, 21): "The government's policy did not receive the **support** of the public.",
    (2, 22): "That theory is backed up by many **case studies**.",
    (2, 23): "Her words have **persuasive power**.",
    # ── N2 synonym questions ─────────────────────────────────────────────
    (2, 28): "I think his opinion is **appropriate** (妥当).",
    (2, 29): "That problem is too **complicated** (複雑) to solve alone.",
    (2, 30): "His attitude was **overbearing** (横柄).",
    (2, 31): "This plan **fell through** (頓挫).",
    # ── N2 grammar fill-blank ────────────────────────────────────────────
    (2, 32): "It is not known **whether** she will come or not.",
    (2, 33): "The problem was resolved **thanks to** him speaking honestly.",
    (2, 34): "**Because** there wasn't enough time, I hurried to finish.",
    (2, 35): "**In order to** pass the exam, I study without fail every day.",
    (2, 36): "**Even though** I wasn't feeling well, I pushed myself to work.",
    (2, 37): "**Due to** the president's decision, the project was cancelled.",
    (2, 39): "This project is scheduled to be completed **by** next month.",
    (2, 40): "Success is something that can be achieved **through** making effort.",
    (2, 41): "This movie is a work that **both** children **and** adults can enjoy.",
    (2, 45): "She quit her job **because of** her best friend.",
    (2, 46): "**No matter what** difficulties there are, it is important not to give up.",
    (2, 47): "**Because** the presentation was insufficiently prepared, it didn't get through to the audience.",
    # ── N2 sentence reorder ──────────────────────────────────────────────
    (2, 55): "He solved the problem **by himself**, without any issues.",
    (2, 56): "She was selected **as a student** representative.",
    (2, 57): "I want to use this summer vacation to spend **quality time**.",
    (2, 58): "The new system was implemented after **repeated** deliberations.",
    (2, 59): "She calmly handled the **sudden** situation.",
    (2, 60): "That research was recognized for its **high** quality.",
    (2, 61): "This problem is **far more than** just difficult.",
    (2, 62): "He went out alone **without telling** anyone.",
    (2, 63): "The company's growth is supported by the **efforts** of its workers.",
    (2, 64): "The results will be announced **as soon as** they are compiled.",
    # ── N2 kanji reading (late) ──────────────────────────────────────────
    (2, 82): "His **abstract** (抽象; read: **ちゅうしょう**) explanation was difficult to understand.",
    (2, 83): "That **practice** (慣行; read: **かんこう**) is now outdated.",
    (2, 84): "He speaks with **dignified** authority (威厳; read: **いげん**).",
    (2, 85): "I feel joy in being able to **contribute** (貢献; read: **こうけん**).",
    (2, 86): "That incident remains **unresolved** (未解決; read: **みかいけつ**).",
    (2, 87): "Her acting is full of **talent** (才能; read: さいのう).",
    # ── N2 fill-blank (late section) ─────────────────────────────────────
    (2, 91): "This problem cannot be **easily** resolved.",
    (2, 92): "Her speech had a great **impact** on the audience.",
    (2, 93): "He used criticism as **nourishment** for new challenges.",
    (2, 94): "The negotiations reached a **delicate** phase.",
    (2, 95): "That policy requires **cuts** to the budget.",
    (2, 96): "She is a **sincere** person trusted by everyone.",
    # ── N1 kanji reading ─────────────────────────────────────────────────
    (1, 0):  "His **hesitant** (逡巡; read: **しゅんじゅん**) attitude prolonged the problem.",
    (1, 1):  "His **passionate** (慷慨; read: **こうがい**) speech moved the audience.",
    (1, 2):  "The remark was evaluated as a **candid** (忌憚; read: **きたん**) opinion.",
    (1, 3):  "Long years of effort **bore fruit** (結実; read: **けつじつ**).",
    (1, 4):  "She expressed her opinion without fearing **friction** (摩擦; read: **まさつ**).",
    (1, 5):  "The policy is built on a **fragile** (脆弱; read: **ぜいじゃく**) foundation.",
    # ── N1 kanji writing ─────────────────────────────────────────────────
    (1, 6):  "In that country, there is a system to support people who are **adrift** (漂流; read: ひょうりゅう).",
    (1, 7):  "His actions **violate** (違反; read: いはん) the law.",
    (1, 8):  "Grasping the **essence** (本質; read: ほんしつ) of the problem is important.",
    (1, 9):  "His plan is nothing but **delusion** (妄想; read: もうそう).",
    # ── N1 vocabulary fill-blank ─────────────────────────────────────────
    (1, 10): "The new system was designed to reflect society's **demands**.",
    (1, 11): "Viewing the problem from a **bird's-eye** perspective will be the key to solving it.",
    (1, 12): "Her thesis **posed a challenge** to existing theories.",
    (1, 13): "The artist faced difficulties with an **indomitable** spirit.",
    (1, 14): "The philosopher's thought still has a **tremendous** influence today.",
    (1, 15): "There are many diverse factors complexly intertwined in economic **fluctuations**.",
    (1, 16): "That discovery was a **groundbreaking** event in the history of science.",
    (1, 17): "That rule has undergone many **changes** over time.",
    # ── N1 synonym questions ─────────────────────────────────────────────
    (1, 18): "That contract was **nullified** (破棄; read: はき).",
    (1, 19): "There is criticism that his claim is **self-righteous** (独善的).",
    (1, 20): "That policy is taking a **roundabout** (迂遠) approach.",
    (1, 21): "Her words and actions contain **contradictions** (矛盾).",
    (1, 22): "That judgment was later criticized as **hasty** (拙速).",
    (1, 23): "That action was called **reckless courage** (蛮勇).",
    (1, 24): "He is known as a **once-in-a-generation** genius (稀代).",
    (1, 25): "That work was described as **difficult to understand** (難解).",
    (1, 26): "It is difficult to grasp the **core** (核心) of that paper.",
    # ── N1 grammar fill-blank ────────────────────────────────────────────
    (1, 27): "**Even among** experts, opinions are divided on this issue.",
    (1, 28): "All the effort was **in vain**, and no results came out.",
    (1, 29): "**In addition to** being a genius, he also doesn't neglect effort.",
    (1, 30): "**No matter how** busy you are, you should at least contact them.",
    (1, 31): "It's **no wonder** she's angry. She was said such terrible things.",
    (1, 32): "The success was, **granted** there was some luck, also due to effort.",
    (1, 33): "**Regardless of** his way of speaking, if the content is correct, it can be accepted.",
    (1, 34): "No matter how much you apologize, there are **things** that cannot be undone.",
    (1, 35): "**Based on** this result, the next countermeasures should be considered.",
    (1, 36): "**Because** the claim **lacks** evidence, it is unconvincing.",
    (1, 37): "**Not only** technically skilled, her work also excels in emotional expression.",
    (1, 38): "We **must** address this problem urgently.",
    (1, 39): "His statement can have the opposite meaning **depending on** the perspective and interpretation.",
    (1, 40): "That decision is now something I **regret endlessly**.",
    (1, 41): "**In light of** the law, such actions are clearly problematic.",
    (1, 42): "She is the type who performs well **only when** under pressure.",
    (1, 43): "**Because** the matter **is urgent**, we need to respond quickly.",
    # ── N1 sentence reorder ──────────────────────────────────────────────
    (1, 44): "I don't think there is **room** to accept his claim.",
    (1, 45): "This problem cannot be solved **overnight**.",
    (1, 46): "**Even amid** difficulties, she tackled it with all her effort.",
    (1, 47): "That system was born after **the people's** repeated discussions.",
    (1, 48): "Scientists continued pursuing the truth **without yielding** to adversity.",
    (1, 49): "His decision was not made **rashly**.",
    (1, 50): "This treaty needs to be fundamentally reviewed **in light of the current situation**.",
    (1, 51): "Researchers reached their conclusion by **collecting and analyzing** data.",
    (1, 52): "That philosophy book holds **timeless** value.",
    (1, 53): "That issue is complicated, with **various factors** intricately intertwined.",
    # ── N1 paragraph reorder ─────────────────────────────────────────────
    (1, 54): (
        "Rearrange the following sentences into a logical order:\n"
        "A. According to this view, people speaking different languages perceive the world from different perspectives.\n"
        "B. On the other hand, there is a counterargument that thinking can exist independently from language.\n"
        "C. The 'Linguistic Relativity Hypothesis' claims that thinking depends on language.\n"
        "D. Evidence: infants understand concepts before acquiring language.\n"
        "E. This debate remains unsettled today, and research from both sides continues.\n\n"
        "Correct order: **C→A→B→D→E**"
    ),
    (1, 55): (
        "Rearrange the following sentences into a logical order:\n"
        "A. However, in today's information-overloaded world, it's difficult for voters to judge based on accurate information.\n"
        "B. The ideal of democracy is that all citizens can participate equally in politics.\n"
        "C. Additionally, the rise of populism threatens democratic functions.\n"
        "D. To address these challenges, media literacy education is considered important.\n\n"
        "Correct order: **B→A→C→D**"
    ),
}


def apply():
    for level in [5, 4, 3, 2, 1]:
        path = DATA / f'n{level}_questions.json'
        if not path.exists():
            print(f'N{level}: not found, skipping')
            continue
        qs = json.load(open(path, encoding='utf-8'))
        changed = 0
        for qi, q in enumerate(qs):
            key = (level, qi)
            if key in TRANSLATIONS:
                old = q.get('question_translation', '')
                new = TRANSLATIONS[key]
                if old != new:
                    q['question_translation'] = new
                    changed += 1
            elif '___' in (q.get('question_translation') or ''):
                print(f'  WARNING N{level} Q{qi}: still has ___ — no patch entry: {q["question_stem"][:60]}')
        if changed:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(qs, f, ensure_ascii=False, indent=2)
            print(f'N{level}: updated {changed} translations')
        else:
            print(f'N{level}: no changes')


if __name__ == '__main__':
    apply()
