
# Language Configuration
# Clip Language: English (en)
# Translation Language: Hebrew (he)

clip_language = Language.find_by(iso_name: 'en')
translation_language = Language.find_by(iso_name: 'he')

medium = Medium.find_or_create_by!(url: 'https://www.youtube.com/watch?v=XbGs_qK2PQA')
phrases_data = [
  [
    "I'm beginning to feel like a Rap God, Rap God",
    "אני מתחיל להרגיש כמו אל ראפ, אל ראפ",
    "00:25"
  ],
  [
    "All my people from the front to the back nod, back nod.",
    "כל האנשים שלי מלפנים ועד אחורה מהנהנים, מהנהנים.",
    "00:29"
  ],
  [
    "Now who thinks their arms are long enough to slapbox, slapbox?",
    "עכשיו מי חושב שיש לו זרועות ארוכות מספיק כדי להתאגרף, להתאגרף?",
    "00:33"
  ],
  [
    "They said I rap like a robot, so call me Rapbot.",
    "הם אמרו שאני עושה ראפ כמו רובוט, אז תקראו לי ראפ-בוט.",
    "00:37"
  ],
  [
    "But for me to rap like a computer, it must be in my genes.",
    "אבל כדי שאעשה ראפ כמו מחשב, זה בטח בגנים שלי.",
    "00:40"
  ],
  [
    "I got a laptop in my back pocket.",
    "יש לי מחשב נייד בכיס האחורי.",
    "00:43"
  ],
  [
    "My pen'll go off when I half-cock it.",
    "העט שלי יתפוצץ כשאני חצי דורך אותו.",
    "00:45"
  ],
  [
    "Got a fat knot from that rap profit.",
    "השגתי הון עצום מרווחי הראפ האלה.",
    "00:47"
  ],
  [
    "Made a livin' and a killin' off it.",
    "התפרנסתי ועשיתי הון מזה.",
    "00:49"
  ],
  [
    "Ever since Bill Clinton was still in office with Monica Lewinsky feelin' on his nutsack.",
    "מאז שביל קלינטון עדיין היה בתפקיד כשמוניקה לווינסקי ממששבת לו את השק.",
    "00:50"
  ],
  [
    "I'm an MC still as honest, but as rude and as indecent as all hell.",
    "אני אם-סי עדיין ישר, אבל גס רוח ובלתי הולם כמו הגיהנום.",
    "00:54"
  ],
  [
    "Syllables, killaholics.",
    "הברות, קטלניות.",
    "00:56"
  ],
  [
    "This lyrical, spiritual, individual, hip-hop.",
    "ההיפ-הופ הלירי, הרוחני, האישי הזה.",
    "00:58"
  ],
  [
    "You don't really wanna get into a pissin' match with this rappity-rap pack.",
    "אתה לא באמת רוצה להיכנס לקרב מילים עם חבילת הראפ המהירה הזו.",
    "01:00"
  ],
  [
    "In a backpack, in the backpack, in the backpack.",
    "בתיק גב, בתיק גב, בתיק גב.",
    "01:03"
  ],
  [
    "Rappity-rap, Rap-pack, Rap-pack, Rap-pack, Rap-pack.",
    "ראפיטי-ראפ, חבילת-ראפ, חבילת-ראפ, חבילת-ראפ, חבילת-ראפ.",
    "01:05"
  ],
  [
    "At exactly same time, I attempt these lyrical acrobatics.",
    "בדיוק באותו זמן, אני מנסה את האקרובטיקה הלירית הזו.",
    "01:08"
  ],
  [
    "And I still be able to bring a motherfuckin' table over the back of a couple of fags.",
    "ואני עדיין אצליח להפוך שולחן ארור על גבם של כמה הומואים.",
    "01:12"
  ],
  [
    "Attacked and had only realized he was ironic.",
    "מותקף ורק אז קלט שהוא אירוני.",
    "01:16"
  ],
  [
    "I was under aftermath after math after the fact.",
    "הייתי תחת השלכות, אחרי החשבון, אחרי העובדות.",
    "01:19"
  ],
  [
    "How could I not blow? All I do is drop F-bombs.",
    "איך לא יכולתי להצליח? כל מה שאני עושה זה לזרוק קללות.",
    "01:21"
  ],
  [
    "Feel my wrath of attack, rappers are havin' a rough time period.",
    "תרגיש את זעם ההתקפה שלי, ראפרים עוברים תקופה קשה.",
    "01:24"
  ],
  [
    "He's a Maxi Pad, actually disastrously bad.",
    "הוא תחבושת היגיינית, למעשה רע באופן קטסטרופלי.",
    "01:28"
  ],
  [
    "For the whack while the masterful reconstructin' this masterpiece.",
    "עבור החלשלוש בזמן שהאמן בונה מחדש את יצירת המופת הזו.",
    "01:31"
  ],
  [
    "And how you beginning to feel like a Rap God, Rap God?",
    "ואיך אתה מתחיל להרגיש כמו אל ראפ, אל ראפ?",
    "01:35"
  ],
  [
    "All my people from the front to the back nod, back nod.",
    "כל האנשים שלי מלפנים ועד אחורה מהנהנים, מהנהנים.",
    "01:39"
  ],
  [
    "Now who thinks their arms are long enough to slapbox, slapbox?",
    "עכשיו מי חושב שיש לו זרועות ארוכות מספיק כדי להתאגרף, להתאגרף?",
    "01:43"
  ],
  [
    "Let me show you maintainin' this shit ain't that hard, that hard.",
    "תן לי להראות לך שלתחזק את החרא הזה זה לא כל כך קשה, כל כך קשה.",
    "01:47"
  ],
  [
    "Everybody wants the key and the secret to rap immortality like I have got.",
    "כולם רוצים את המפתח והסוד לחיי נצח של ראפ כמו שיש לי.",
    "01:50"
  ],
  [
    "Well, they be truthfully, the blueprint, they be pagan, you be the exuberance.",
    "ובכן, הם באמת, תכנית העבודה, הם עובדי אלילים, אתה השפע.",
    "01:54"
  ],
  [
    "Everybody loves the rude from a nuisance and earth like an asteroid hitting.",
    "כולם אוהבים את הבוטה ממטרד, וכדור הארץ כמו אסטרואיד שפוגע.",
    "01:58"
  ],
  [
    "Nothin' but truth for the moon since MC's get taken to school with this music 'cause I use it.",
    "רק אמת לירח מאז שאמ-סיז נשלחים לבית ספר עם המוזיקה הזו כי אני משתמש בה.",
    "02:01"
  ],
  [
    "As a vehicle to bust the rhyme.",
    "ככלי לשבור את החרוז.",
    "02:05"
  ],
  [
    "Yeah, I lead a new school full of students.",
    "כן, אני מוביל בית ספר חדש מלא בתלמידים.",
    "02:07"
  ],
  [
    "Me, I'm a product of Rakim, Lakim Shabazz, 2Pac, N.W.A.",
    "אני, אני תוצר של ראקים, לאקים שבז, טופאק, אן-דאבליו-איי.",
    "02:09"
  ],
  [
    "Cube, Hey Doc, Ren, Yella, Eazy, thank you, they got Slim.",
    "קיוּב, היי דוק, רן, יֶלָה, איזי, תודה, הם קיבלו את סלים.",
    "02:13"
  ],
  [
    "Inspired enough to one day grow up, blow up and be in a position.",
    "קיבלו מספיק השראה כדי שיום אחד יגדלו, יתפוצצו ויהיו בעמדה.",
    "02:16"
  ],
  [
    "To meet Run DMC and induct them into the motherfuckin' rock and roll hall of fame.",
    "לפגוש את ראן די-אם-סי ולהכניס אותם להיכל התהילה המזורגג של הרוק אנד רול.",
    "02:20"
  ],
  [
    "Even though I walk in a church and burst in a ball of flames.",
    "למרות שאני נכנס לכנסייה ומתפוצץ בכדור להבות.",
    "02:24"
  ],
  [
    "Only hall of fame I'll be inducted in is the alcohol of fame.",
    "היכל התהילה היחיד שאכניס אליו הוא היכל התהילה של האלכוהול.",
    "02:27"
  ],
  [
    "On the wall of shame.",
    "על קיר הבושה.",
    "02:30"
  ],
  [
    "You fags think it's all a game.",
    "אתם חושבים שזה רק משחק.",
    "02:31"
  ],
  [
    "Till I walk a flock of flames off a plank and tell me what in the fuck are you thinkin'?",
    "עד שאוריד להקת להבות מקרש ותגיד לי מה לעזאזל אתה חושב?",
    "02:33"
  ],
  [
    "Little gay lookin' boy.",
    "ילדון שנראה הומו.",
    "02:37"
  ],
  [
    "So gay I can barely say it with a straight face lookin' boy.",
    "כל כך הומו שאני בקושי יכול לומר את זה עם פנים ישרות, ילדון.",
    "02:39"
  ],
  [
    "You witnessed a massacre like you're watching a church gatherin' take place lookin' boy.",
    "היית עד לטבח כאילו אתה צופה בכנסייה מתרחשת, ילדון.",
    "02:42"
  ],
  [
    "Boy, gay, that boy's gay, that's all they say lookin' boy.",
    "ילד, הומו, הילד הזה הומו, זה כל מה שהם אומרים, ילדון.",
    "02:46"
  ],
  [
    "You get a thumbs up, pat in the back and a way to go from your label everyday lookin' boy.",
    "אתה מקבל לייק, טפיחה על השכם ו-'כל הכבוד' מהלייבל שלך כל יום, ילדון.",
    "02:49"
  ],
  [
    "Hey lookin' boy, what's a gay lookin' boy?",
    "היי ילדון, מה זה ילדון שנראה הומו?",
    "02:53"
  ],
  [
    "I get a hell yeah from Tray lookin' boy.",
    "אני מקבל 'בטח לעזאזל' מטְרֶיי, ילדון.",
    "02:56"
  ],
  [
    "I'mma work for everything I have, never asked nobody for shit, get out my face lookin' boy.",
    "אני הולך לעבוד בשביל כל מה שיש לי, אף פעם לא ביקשתי כלום מאף אחד, צא לי מהפנים, ילדון.",
    "02:58"
  ],
  [
    "Basically, boy, you never gonna be capable of keepin' up with the same pace lookin' boy.",
    "בעצם, ילד, אתה אף פעם לא תהיה מסוגל לעמוד בקצב הזה, ילדון.",
    "03:02"
  ],
  [
    "'Cause I'm beginnin' to feel like a Rap God, Rap God.",
    "כי אני מתחיל להרגיש כמו אל ראפ, אל ראפ.",
    "03:06"
  ],
  [
    "All my people from the front to the back nod, back nod.",
    "כל האנשים שלי מלפנים ועד אחורה מהנהנים, מהנהנים.",
    "03:10"
  ],
  [
    "The way I'm race 'round the track, call me NASCAR, NASCAR.",
    "הדרך בה אני דוהר במסלול, תקרא לי נאסקאר, נאסקאר.",
    "03:14"
  ],
  [
    "Dale Earnhardt of the trailer park, the white trash god.",
    "דייל ארנהארד של פארק הקרוואנים, אל הוואייט טראש.",
    "03:18"
  ],
  [
    "Kneel before General Zod, this planet's Krypton, no Asgard, Asgard.",
    "כרעו ברך לפני גנרל זוד, הכוכב הזה הוא קריפטון, אין אסגרד, אסגרד.",
    "03:21"
  ],
  [
    "You be Thor, I'll be Odin, you rodent, I'm omnipotent.",
    "אתה תהיה ת'ור, אני אהיה אודין, אתה מכרסם, אני כל יכול.",
    "03:26"
  ],
  [
    "Let off then I'm reloaded, immaculately with these rhymes I'm totin'.",
    "משחרר ואז אני טעון מחדש, בטהרה עם החרוזים האלה שאני נושא.",
    "03:30"
  ],
  [
    "And I should not be woken, I'm the walking dead, but I'm just a talking head, a zombie floatin'.",
    "ואני לא צריך להתעורר, אני המת המהלך, אבל אני רק ראש מדבר, זומבי מרחף.",
    "03:33"
  ],
  [
    "But I got your mom deep throatin'.",
    "אבל אמא שלך עושה לי תהום-גרון.",
    "03:38"
  ],
  [
    "I'm out my ramen noodle, we have nothing in common, poodle.",
    "אני לא שפוי, אין לנו שום דבר במשותף, פודל.",
    "03:40"
  ],
  [
    "I'm a Doberman, pinch yourself in the arm and pay homage, pupil.",
    "אני דוברמן, צבוט את עצמך בזרוע ותחלוק כבוד, תלמיד.",
    "03:43"
  ],
  [
    "It's me.",
    "זה אני.",
    "03:47"
  ],
  [
    "My honesty's brutal, but it's honestly feudal if I don't utilize what I do though.",
    "הכנות שלי אכזרית, אבל זה בכנות חסר תועלת אם אני לא מנצל את מה שאני עושה.",
    "03:48"
  ],
  [
    "For good at least once in a while so I wanna make sure somewhere in a chicken scratch I scribble and doodle.",
    "לטובה לפחות פעם ב... אז אני רוצה לוודא שבאיזשהו מקום בכתב חסר צורה אני משרבט ומקשקש.",
    "03:52"
  ],
  [
    "Enough rhymes to maybe try to help get some people through tough times.",
    "מספיק חרוזים כדי אולי לנסות לעזור לאנשים לעבור תקופות קשות.",
    "03:56"
  ],
  [
    "But I gotta keep a few punch lines just in case 'cause even I'm unsatisfied.",
    "אבל אני צריך לשמור כמה שורות מחץ למקרה שאני לא מרוצה.",
    "04:00"
  ],
  [
    "Rappers are hungry, lookin' at me like it's lunch time.",
    "ראפרים רעבים, מסתכלים עליי כאילו זו שעת צהריים.",
    "04:04"
  ],
  [
    "I know there was a time where once I was king of the underground.",
    "אני יודע שהייתה תקופה שבה הייתי מלך האנדרגראונד.",
    "04:07"
  ],
  [
    "But I still rap like I'm on my Pharoahe Monch grind.",
    "אבל אני עדיין עושה ראפ כאילו אני בשיא כוחו של פארוה מונץ'.",
    "04:10"
  ],
  [
    "So I crunch rhymes, but sometimes when you come back.",
    "אז אני טוחן חרוזים, אבל לפעמים כשאתה חוזר.",
    "04:13"
  ],
  [
    "Up here with the skin color of mine, you get too big and it becomes tryin'.",
    "לכאן למעלה עם צבע העור שלי, אתה נהיה גדול מדי וזה נהיה מתיש.",
    "04:16"
  ],
  [
    "To censure you like that one line I said, on 'I'm Back' from the Mathers LP 1.",
    "לצנזר אותך כמו השורה ההיא שאמרתי, ב'אני חוזר' מהאלבום 'Mathers LP 1'.",
    "04:20"
  ],
  [
    "When I tried to say I take seven kids from Columbine.",
    "כשניסיתי לומר שאני לוקח שבעה ילדים מקולומביין.",
    "04:25"
  ],
  [
    "Put 'em all in a line, add an AK-47, a revolver and a .9.",
    "שים את כולם בשורה, הוסף איי-קיי-47, אקדח ו-9 מ\"מ.",
    "04:28"
  ],
  [
    "See if I get away with it now that I ain't as big as I was.",
    "נראה אם אתחמק מזה עכשיו כשאני לא גדול כמו שהייתי.",
    "04:32"
  ],
  [
    "But I'm morphin' into an immortal, comin' through the portal.",
    "אבל אני משתנה לבן אלמוות, מגיע דרך הפורטל.",
    "04:35"
  ],
  [
    "You're stuck in a time warp from 2004 though.",
    "אתה תקוע בעיוות זמן משנת 2004.",
    "04:39"
  ],
  [
    "And I don't know what the fuck that you rhyme for.",
    "ואני לא יודע על מה לעזאזל אתה מתחרז.",
    "04:42"
  ],
  [
    "You're pointless as Rapunzel with fuckin' cornrows.",
    "אתה חסר תועלת כמו רפונזל עם קורנרוז ארורים.",
    "04:44"
  ],
  [
    "You're like normal, fuck bein' normal.",
    "אתה כמו נורמלי, לעזאזל עם להיות נורמלי.",
    "04:48"
  ],
  [
    "And I just bought a new ray gun from the future just to come and shoot ya.",
    "וקניתי עכשיו רובה לייזר חדש מהעתיד רק כדי לבוא ולירות בך.",
    "04:50"
  ],
  [
    "Like when Fabolous made Ray J mad, 'cause Fab said he looked like a fag.",
    "כמו כשפבולוס הרגיז את ריי ג'יי, כי פאב אמר שהוא נראה כמו מתרומם.",
    "04:53"
  ],
  [
    "In Ray J's math, see him into a man while he played Ray J, nano.",
    "ב'ריי ג'ייז מת' (Mathers LP), הוא ראה אותו כגבר בזמן שהוא שיחק את ריי ג'יי, ננו.",
    "04:57"
  ],
  [
    "Nano, man, that was a 24/7 special on the cable channel.",
    "ננו, בנאדם, זו הייתה תוכנית מיוחדת 24/7 בערוץ הכבלים.",
    "05:00"
  ],
  [
    "So Ray J went straight to the radio station the very next day.",
    "אז ריי ג'יי הלך ישר לתחנת הרדיו כבר למחרת.",
    "05:03"
  ],
  [
    "Hey, Fab, I'm gonna kill you.",
    "היי, פאב, אני הולך להרוג אותך.",
    "05:06"
  ],
  [
    "Lyrics comin' at you with supersonic speed, (J.F.K.).",
    "מילים מגיעות אליך במהירות על-קולית, (ג'יי.אף.קיי.).",
    "05:08"
  ],
  [
    "Summa-lumma, dooma-lumma, you assumin' I'm a human.",
    "סומה-לומה, דומה-לומה, אתם מניחים שאני בן אדם.",
    "05:11"
  ],
  [
    "What I gotta do to get it through to you? I'm superhuman.",
    "מה אני צריך לעשות כדי שתבינו? אני סופר-אנושי.",
    "05:13"
  ],
  [
    "Inventin' and I'm revvin' and I'm never ever gonna be relevant.",
    "ממציא ואני מאיץ ואני לעולם לא אפסיק להיות רלוונטי.",
    "05:15"
  ],
  [
    "Or rapping again, so anything you say is pick it stain.",
    "או לעשות ראפ שוב, אז כל מה שתגידו הוא כתם חסר חשיבות.",
    "05:18"
  ],
  [
    "And I'm doing and I'm devastatin', more than ever demonstratin'.",
    "ואני עושה ואני הורס, יותר מתמיד מדגים.",
    "05:20"
  ],
  [
    "How to give a motherfuckin' audience a feelin' like it's never been felt.",
    "איך לתת לקהל ארור הרגשה שמעולם לא הרגישו.",
    "05:23"
  ],
  [
    "And I know the haters are forever waitin' for the day that they can say I fell off.",
    "ואני יודע שהשונאים מחכים לנצח ליום שבו יוכלו לומר שנפלתי.",
    "05:27"
  ],
  [
    "They'll be celebratin' 'cause I know the way to get 'em motivated.",
    "הם יחגגו כי אני יודע איך לגרום להם מוטיבציה.",
    "05:30"
  ],
  [
    "I make elevatin' music, you make elevator music.",
    "אני יוצר מוזיקה מעלה, אתם יוצרים מוזיקת מעליות.",
    "05:32"
  ],
  [
    "Oh, he's too mainstream. Well that's what they do when they get jealous and confused it.",
    "הו, הוא יותר מדי מיינסטרים. ובכן, זה מה שהם עושים כשהם מקנאים ומבלבלים את זה.",
    "05:34"
  ],
  [
    "It's not hip-hop, it's pop, 'cause I found a hella way to fuse it.",
    "זה לא היפ-הופ, זה פופ, כי מצאתי דרך מטורפת למזג את זה.",
    "05:38"
  ],
  [
    "With rock, shock-rap with Doc.",
    "עם רוק, שוק-ראפ עם דוק.",
    "05:41"
  ],
  [
    "Throw on Lose Yourself, I'mma make 'em lose it.",
    "תפעיל את 'לאבד את עצמך', אני אגרום להם לאבד את זה.",
    "05:44"
  ],
  [
    "I don't know how to make songs like that.",
    "אני לא יודע איך ליצור שירים כאלה.",
    "05:46"
  ],
  [
    "I don't know what words to use.",
    "אני לא יודע באילו מילים להשתמש.",
    "05:48"
  ],
  [
    "Lemme know when it occurs to you while I'm rippin' any one of these verses the verses you.",
    "תגיד לי כשזה עולה לך בראש בזמן שאני קורע כל אחד מהבתים האלה, ואני קורע אותך.",
    "05:50"
  ],
  [
    "It's curtains, I'm inadvertently hurtin' you.",
    "זה הסוף, אני פוגע בך שלא בכוונה.",
    "05:53"
  ],
  [
    "How many verses I gotta murder too?",
    "כמה בתים אני צריך לרצוח גם?",
    "05:56"
  ],
  [
    "Proof that if you were half as nice, yo, songs you could sacrifice virgins to.",
    "הוכחה שאם היית חצי נחמד, יו, לשירים שלך היית יכול להקריב בתולות.",
    "05:58"
  ],
  [
    "School flunky, pill junkie.",
    "נשר מבית ספר, מכור לכדורים.",
    "06:01"
  ],
  [
    "But look at the accolades, skills brought me.",
    "אבל תראה את ההערכה, הכישורים הביאו לי.",
    "06:03"
  ],
  [
    "Full of myself, but still hungry.",
    "מלא בעצמי, אבל עדיין רעב.",
    "06:06"
  ],
  [
    "I bully myself 'cause I make me do what I put my mind to.",
    "אני מתעמר בעצמי כי אני גורם לעצמי לעשות מה שאני מחליט.",
    "06:08"
  ],
  [
    "When I'm a million leagues above you.",
    "כשאני מיליון ליגות מעליך.",
    "06:11"
  ],
  [
    "Ill when I speak in tongues but it's still tongue in cheek.",
    "חולה כשאני מדבר בלשונות אבל זה עדיין בלשון המעטה.",
    "06:14"
  ],
  [
    "Fuck you, I'm drunk, so Satan, take the fuckin' wheel.",
    "לעזאזל איתך, אני שיכור, אז שטן, קח את ההגה הארור.",
    "06:17"
  ],
  [
    "I'm asleep in the front seat, bumpin' heavy D and the Boyz.",
    "אני ישן במושב הקדמי, מאזין ל'האבי די אנד דה בויז'.",
    "06:20"
  ],
  [
    "Still chunky, but funky.",
    "עדיין שמנמן, אבל פאנקי.",
    "06:23"
  ],
  [
    "But in my head there's somethin' I can feel tuggin' and strugglin'.",
    "אבל בראש שלי יש משהו שאני מרגיש מושך ונאבק.",
    "06:26"
  ],
  [
    "Angels fight with devils and here's what they want from me.",
    "מלאכים נלחמים עם שדים והנה מה שהם רוצים ממני.",
    "06:29"
  ],
  [
    "They're askin' me to eliminate some of the women hate.",
    "הם מבקשים ממני לחסל קצת משנאת הנשים.",
    "06:33"
  ],
  [
    "But if you take into consideration the bitter hate that I had.",
    "אבל אם תיקח בחשבון את השנאה המרה שהייתה לי.",
    "06:36"
  ],
  [
    "Then you may be a little patient and more sympathetic to the situation.",
    "אז אולי תהיה קצת סבלני ויותר סימפטי למצב.",
    "06:39"
  ],
  [
    "And understand the discrimination.",
    "ותבין את האפליה.",
    "06:43"
  ],
  [
    "But fuck it, life's handing you lemons.",
    "אבל לעזאזל, החיים נותנים לך לימונים.",
    "06:45"
  ],
  [
    "Make lemonade then.",
    "תכין לימונדה אז.",
    "06:48"
  ],
  [
    "But if I can't batter the women, how the fuck am I supposed to bake them a cake then?",
    "אבל אם אני לא יכול להרביץ לנשים, איך לעזאזל אני אמור לאפות להן עוגה אז?",
    "06:50"
  ],
  [
    "Don't mistake it for Satan.",
    "אל תתבלבלו עם שטן.",
    "06:53"
  ],
  [
    "Don't mistake if you think I need to be overseas and take a vacation.",
    "אל תטעו אם אתם חושבים שאני צריך להיות בחו\"ל ולצאת לחופשה.",
    "06:56"
  ],
  [
    "To trip abroad and make a ball of facial.",
    "לטייל בחו\"ל ולעשות משהו מטופש.",
    "07:00"
  ],
  [
    "Don't be a retard, be a king.",
    "אל תהיה מפגר, תהיה מלך.",
    "07:02"
  ],
  [
    "Think not.",
    "לא חושב.",
    "07:05"
  ],
  [
    "Why be a king when you could be a god?",
    "למה להיות מלך כשאתה יכול להיות אל?",
    "07:06"
  ]
];

c = Course.find_or_create_by!(slug: 'rap-god')
c.name = 'rap-god'
c.main_media_url = 'https://www.youtube.com/watch?v=XbGs_qK2PQA'
c.save!
c.reload
c.lessons.destroy_all

Lesson.where("slug like 'rap-god%'").destroy_all
medium.phrases.destroy_all

# Create phrases in DB
# Each phrase contains text in both clip language and translation language
phrases = phrases_data.map do |text_clip_language, text_translation_language, timestamp|
  Phrase.create!(
    l1: clip_language,
    l2: translation_language,
    text_l1: text_clip_language,
    text_l2: text_translation_language,
    timestamp: timestamp,
    medium: medium
  )
end
medium.phrases.reload

# Create Lessons in the DB

phrase = phrases[0]
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: ["aim"])
phrase.add_token_translation("beginning", 0, "מתחיל", 0, similar_sound: [])
phrase.add_token_translation("to feel", 0, "להרגיש", 0, similar_sound: [])
phrase.add_token_translation("like", 0, "כמו", 0, similar_sound: ["light"])
phrase.add_token_translation("Rap God", 0, "אל ראפ", 0, similar_sound: ["wrap god"])
phrase.add_token_translation("Rap God", 1, "אל ראפ", 1, similar_sound: ["wrap god"])

phrase = phrases[1]
phrase.add_token_translation("All", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("my people", 0, "האנשים שלי", 0, similar_sound: [])
phrase.add_token_translation("from the", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("front", 0, "קדימה", 0, similar_sound: [])
phrase.add_token_translation("to the", 0, "ועד", 0, similar_sound: [])
phrase.add_token_translation("back", 0, "אחורה", 0, similar_sound: [])
phrase.add_token_translation("nod", 0, "מהנהנים", 0, similar_sound: [])
phrase.add_token_translation("back", 1, "אחורה", 1, similar_sound: [])
phrase.add_token_translation("nod", 1, "מהנהנים", 1, similar_sound: [])

phrase = phrases[2]
phrase.add_token_translation("Now", 0, "עכשיו", 0, similar_sound: [])
phrase.add_token_translation("who", 0, "מי", 0, similar_sound: [])
phrase.add_token_translation("thinks", 0, "חושב", 0, similar_sound: ["sinks"])
phrase.add_token_translation("their", 0, "שלהם", 0, similar_sound: ["there","they're"])
phrase.add_token_translation("arms", 0, "ידיים", 0, similar_sound: ["harms"])
phrase.add_token_translation("are", 0, "הן", 0, similar_sound: ["our","hour"])
phrase.add_token_translation("long enough", 0, "ארוכות מספיק", 0, similar_sound: [])
phrase.add_token_translation("to slapbox", 0, "כדי להתאגרף במכות פתוחות", 0, similar_sound: [])
phrase.add_token_translation("slapbox", 1, "להתאגרף במכות פתוחות", 0, similar_sound: [])

phrase = phrases[3]
phrase.add_token_translation("They", 0, "הם", 0, similar_sound: [])
phrase.add_token_translation("said", 0, "אמרו", 0, similar_sound: ["sad","fed"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("rap", 0, "מראפרפ", 0, similar_sound: ["wrap","trap"])
phrase.add_token_translation("like", 0, "כמו", 0, similar_sound: ["light","bike"])
phrase.add_token_translation("a robot", 0, "רובוט", 0, similar_sound: ["robbed it"])
phrase.add_token_translation("so", 0, "אז", 0, similar_sound: ["sew","sow"])
phrase.add_token_translation("call", 0, "תקראו", 0, similar_sound: ["hall","ball"])
phrase.add_token_translation("me", 0, "לי", 0, similar_sound: ["key","see"])
phrase.add_token_translation("Rapbot", 0, "ראפבוט", 0, similar_sound: ["robot"])

phrase = phrases[4]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: ["butt","bat"])
phrase.add_token_translation("for me", 0, "בשבילי", 0, similar_sound: [])
phrase.add_token_translation("to rap", 0, "לראפרפ", 0, similar_sound: ["wrap","trap"])
phrase.add_token_translation("like a", 0, "כמו", 0, similar_sound: ["light","lick"])
phrase.add_token_translation("computer", 0, "מחשב", 0, similar_sound: [])
phrase.add_token_translation("it must be", 0, "זה חייב להיות", 0, similar_sound: [])
phrase.add_token_translation("in my genes", 0, "בגנים שלי", 0, similar_sound: ["in my jeans"])

phrase = phrases[5]
phrase.add_token_translation("I got", 0, "יש לי", 0, similar_sound: [])
phrase.add_token_translation("laptop", 0, "מחשב נייד", 0, similar_sound: [])
phrase.add_token_translation("in", 0, "ב", 0, similar_sound: [])
phrase.add_token_translation("my", 0, "שלי", 0, similar_sound: [])
phrase.add_token_translation("back pocket", 0, "כיס אחורי", 0, similar_sound: [])

phrase = phrases[6]
phrase.add_token_translation("My", 0, "שלי", 0, similar_sound: [])
phrase.add_token_translation("pen", 0, "העט", 0, similar_sound: ["men","ten"])
phrase.add_token_translation("go off", 0, "יירה", 0, similar_sound: [])
phrase.add_token_translation("when", 0, "כש", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("half", 0, "חצי", 0, similar_sound: ["laugh","calf"])
phrase.add_token_translation("cock", 0, "דורך", 0, similar_sound: ["lock","rock"])
phrase.add_token_translation("it", 0, "אותו", 0, similar_sound: [])

phrase = phrases[7]
phrase.add_token_translation("Got", 0, "השגתי", 0, similar_sound: ["hot","pot","dot"])
phrase.add_token_translation("fat", 0, "שמן", 0, similar_sound: ["fought","vat","cat"])
phrase.add_token_translation("knot", 0, "צרור", 0, similar_sound: ["not","naught","cot"])
phrase.add_token_translation("from", 0, "מ", 0, similar_sound: ["form","farm","prom"])
phrase.add_token_translation("that", 0, "ההוא", 0, similar_sound: ["bat","cat","hat"])
phrase.add_token_translation("rap", 0, "הראפ", 0, similar_sound: ["wrap","trap","tap"])
phrase.add_token_translation("profit", 0, "רווח", 0, similar_sound: ["prophet","off it","fit"])

phrase = phrases[8]
phrase.add_token_translation("Made", 0, "עשיתי", 0, similar_sound: ["maid","paid","fade"])
phrase.add_token_translation("a livin'", 0, "פרנסה", 0, similar_sound: ["a given","a driven"])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["end","hand"])
phrase.add_token_translation("a killin'", 0, "קופה", 0, similar_sound: ["a chilling","a filling"])
phrase.add_token_translation("off it", 0, "מזה", 0, similar_sound: ["of it","often"])

phrase = phrases[9]
phrase.add_token_translation("Ever since", 0, "מאז ש", 0, similar_sound: [])
phrase.add_token_translation("Bill Clinton", 0, "ביל קלינטון", 0, similar_sound: [])
phrase.add_token_translation("was", 0, "היה", 0, similar_sound: [])
phrase.add_token_translation("still", 0, "עדיין", 0, similar_sound: [])
phrase.add_token_translation("in office", 0, "בתפקיד", 0, similar_sound: [])
phrase.add_token_translation("with", 0, "עם", 0, similar_sound: [])
phrase.add_token_translation("Monica Lewinsky", 0, "מוניקה לווינסקי", 0, similar_sound: [])
phrase.add_token_translation("feelin' on", 0, "ממששת לו את", 0, similar_sound: [])
phrase.add_token_translation("his", 0, "ה", 0, similar_sound: [])
phrase.add_token_translation("nutsack", 0, "ביצים", 0, similar_sound: [])

phrase = phrases[10]
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: ["aim"])
phrase.add_token_translation("an MC", 0, "אם סי", 0, similar_sound: [])
phrase.add_token_translation("still", 0, "עדיין", 0, similar_sound: ["steel","stile"])
phrase.add_token_translation("as", 0, "כמו", 0, similar_sound: ["has","ass"])
phrase.add_token_translation("honest", 0, "ישר", 0, similar_sound: ["on us"])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["butt","boat"])
phrase.add_token_translation("as", 1, "כמו", 1, similar_sound: ["has","ass"])
phrase.add_token_translation("rude", 0, "גס רוח", 0, similar_sound: ["rood","root"])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["end","hand"])
phrase.add_token_translation("as", 2, "כמו", 2, similar_sound: ["has","ass"])
phrase.add_token_translation("indecent", 0, "לא הגון", 0, similar_sound: ["in decent","indeed sent"])
phrase.add_token_translation("as all hell", 0, "לעזאזל", 0, similar_sound: ["awl hell","old hell"])

phrase = phrases[11]
phrase.add_token_translation("Syllables", 0, "הֲבָרוֹת", 0, similar_sound: [])
phrase.add_token_translation("killaholics", 0, "קִילָהוֹלִיקִים", 0, similar_sound: ["alcoholics"])

phrase = phrases[12]
phrase.add_token_translation("This", 0, "זה", 0, similar_sound: [])
phrase.add_token_translation("lyrical", 0, "לירי", 0, similar_sound: [])
phrase.add_token_translation("spiritual", 0, "רוחני", 0, similar_sound: [])
phrase.add_token_translation("individual", 0, "אינדיבידואלי", 0, similar_sound: [])
phrase.add_token_translation("hip-hop", 0, "היפ-הופ", 0, similar_sound: [])

phrase = phrases[13]
phrase.add_token_translation("You", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("don't really wanna", 0, "לא באמת רוצה", 0, similar_sound: [])
phrase.add_token_translation("get into", 0, "להיכנס ל", 0, similar_sound: [])
phrase.add_token_translation("a pissin' match", 0, "קרב התנצחויות", 0, similar_sound: [])
phrase.add_token_translation("with", 0, "עם", 0, similar_sound: [])
phrase.add_token_translation("this", 0, "הזו", 0, similar_sound: [])
phrase.add_token_translation("rappity-rap pack", 0, "חבורת הראפ", 0, similar_sound: [])

phrase = phrases[14]
phrase.add_token_translation("In a backpack", 0, "בתיק גב", 0, similar_sound: [])
phrase.add_token_translation("in the backpack", 0, "בתיק הגב", 0, similar_sound: [])
phrase.add_token_translation("in the backpack", 1, "בתיק הגב", 1, similar_sound: [])

phrase = phrases[15]
phrase.add_token_translation("Rappity-rap", 0, "ראפיטי-ראפ", 0, similar_sound: [])
phrase.add_token_translation("Rap-pack", 0, "ראפ-פאק", 0, similar_sound: ["backpack","trap pack"])
phrase.add_token_translation("Rap-pack", 1, "ראפ-פאק", 1, similar_sound: ["backpack","trap pack"])
phrase.add_token_translation("Rap-pack", 2, "ראפ-פאק", 2, similar_sound: ["backpack","trap pack"])
phrase.add_token_translation("Rap-pack", 3, "ראפ-פאק", 3, similar_sound: ["backpack","trap pack"])

phrase = phrases[16]
phrase.add_token_translation("At exactly same time", 0, "באותו זמן בדיוק", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("attempt", 0, "מנסה", 0, similar_sound: ["contempt","exempt"])
phrase.add_token_translation("these lyrical acrobatics", 0, "את האקרובטיקה הלירית הזו", 0, similar_sound: [])

phrase = phrases[17]
phrase.add_token_translation("And", 0, "ו", 0, similar_sound: ["hand","sand"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("still", 0, "עדיין", 0, similar_sound: ["steel","skill"])
phrase.add_token_translation("be able to", 0, "להיות מסוגל", 0, similar_sound: ["table","fable"])
phrase.add_token_translation("bring", 0, "להביא", 0, similar_sound: ["ring","sing"])
phrase.add_token_translation("a motherfuckin'", 0, "ארור", 0, similar_sound: [])
phrase.add_token_translation("table", 0, "שולחן", 0, similar_sound: ["cable","stable"])
phrase.add_token_translation("over", 0, "מעל", 0, similar_sound: ["clover","rover"])
phrase.add_token_translation("the back of", 0, "הגב של", 0, similar_sound: ["pack","sack"])
phrase.add_token_translation("a couple of", 0, "כמה", 0, similar_sound: ["bubble","double"])
phrase.add_token_translation("fags", 0, "מתרוממים", 0, similar_sound: ["bags","lags"])

phrase = phrases[18]
phrase.add_token_translation("Attacked", 0, "הותקף", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["end"])
phrase.add_token_translation("had only realized", 0, "רק הבין", 0, similar_sound: [])
phrase.add_token_translation("he", 0, "הוא", 0, similar_sound: ["we"])
phrase.add_token_translation("was", 0, "היה", 0, similar_sound: ["wars"])
phrase.add_token_translation("ironic", 0, "אירוני", 0, similar_sound: ["iconic"])

phrase = phrases[19]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("was", 0, "הייתי", 0, similar_sound: [])
phrase.add_token_translation("under", 0, "תחת", 0, similar_sound: [])
phrase.add_token_translation("aftermath", 0, "השלכות", 0, similar_sound: [])
phrase.add_token_translation("after", 0, "אחרי", 0, similar_sound: [])
phrase.add_token_translation("math", 0, "מתמטיקה", 0, similar_sound: [])
phrase.add_token_translation("after", 1, "אחרי", 1, similar_sound: [])
phrase.add_token_translation("the fact", 0, "מעשה", 0, similar_sound: [])

phrase = phrases[20]
phrase.add_token_translation("How could I not", 0, "איך לא יכולתי", 0, similar_sound: [])
phrase.add_token_translation("blow", 0, "להתפוצץ", 0, similar_sound: ["low","flow","glow"])
phrase.add_token_translation("All I do is", 0, "כל מה שאני עושה זה", 0, similar_sound: [])
phrase.add_token_translation("drop", 0, "לזרוק", 0, similar_sound: ["prop","stop","crop"])
phrase.add_token_translation("F-bombs", 0, "קללות", 0, similar_sound: ["fee-bombs","free-bombs"])

phrase = phrases[21]
phrase.add_token_translation("Feel", 0, "תרגישו", 0, similar_sound: ["heel","peel"])
phrase.add_token_translation("my", 0, "שלי", 0, similar_sound: [])
phrase.add_token_translation("wrath", 0, "זעם", 0, similar_sound: ["path","math"])
phrase.add_token_translation("of", 0, "של", 0, similar_sound: [])
phrase.add_token_translation("attack", 0, "התקפה", 0, similar_sound: ["back","pack"])
phrase.add_token_translation("rappers", 0, "ראפרים", 0, similar_sound: ["wrappers"])
phrase.add_token_translation("are havin'", 0, "עוברים", 0, similar_sound: ["heaven"])
phrase.add_token_translation("a rough time period", 0, "תקופה קשה", 0, similar_sound: [])

phrase = phrases[22]
phrase.add_token_translation("He's", 0, "הוא", 0, similar_sound: [])
phrase.add_token_translation("a Maxi Pad", 0, "פד", 0, similar_sound: [])
phrase.add_token_translation("actually", 0, "למעשה", 0, similar_sound: [])
phrase.add_token_translation("disastrously", 0, "באופן קטסטרופלי", 0, similar_sound: [])
phrase.add_token_translation("bad", 0, "גרוע", 0, similar_sound: ["bed","bade"])

phrase = phrases[23]
phrase.add_token_translation("For the whack", 0, "עבור החלשים", 0, similar_sound: ["for the back","for the track"])
phrase.add_token_translation("while", 0, "בזמן ש", 0, similar_sound: ["wild","whale"])
phrase.add_token_translation("the masterful", 0, "האמן", 0, similar_sound: ["the master full","the past full"])
phrase.add_token_translation("reconstructin'", 0, "משחזר", 0, similar_sound: ["reconstruct in","reconstruct and"])
phrase.add_token_translation("this", 0, "הזו", 0, similar_sound: ["kiss","miss"])
phrase.add_token_translation("masterpiece", 0, "יצירת מופת", 0, similar_sound: ["master peace","master piece"])

phrase = phrases[24]
phrase.add_token_translation("And", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("how", 0, "איך", 0, similar_sound: ["now","cow"])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: ["new","do"])
phrase.add_token_translation("beginning to feel", 0, "מתחיל להרגיש", 0, similar_sound: [])
phrase.add_token_translation("like", 0, "כמו", 0, similar_sound: ["light","bike"])
phrase.add_token_translation("Rap God", 0, "אל ראפ", 0, similar_sound: [])
phrase.add_token_translation("Rap God", 1, "אל ראפ", 1, similar_sound: [])

phrase = phrases[25]
phrase.add_token_translation("All my people", 0, "כל האנשים שלי", 0, similar_sound: [])
phrase.add_token_translation("from the front", 0, "מקדימה", 0, similar_sound: [])
phrase.add_token_translation("to the back", 0, "ועד מאחור", 0, similar_sound: [])
phrase.add_token_translation("nod", 0, "מהנהנים", 0, similar_sound: ["not","gnawed"])
phrase.add_token_translation("back nod", 0, "מהנהנים", 1, similar_sound: [])
phrase.add_token_translation("back nod", 1, "מהנהנים", 2, similar_sound: [])

phrase = phrases[26]
phrase.add_token_translation("Now", 0, "עכשיו", 0, similar_sound: [])
phrase.add_token_translation("who", 0, "מי", 0, similar_sound: [])
phrase.add_token_translation("thinks", 0, "חושב", 0, similar_sound: ["sinks"])
phrase.add_token_translation("their", 0, "שלהם", 0, similar_sound: ["there","they're"])
phrase.add_token_translation("arms", 0, "ידיים", 0, similar_sound: ["harms"])
phrase.add_token_translation("are", 0, "הן", 0, similar_sound: ["our","hour"])
phrase.add_token_translation("long enough", 0, "ארוכות מספיק", 0, similar_sound: [])
phrase.add_token_translation("to slapbox", 0, "כדי להתאגרף במכות פתוחות", 0, similar_sound: [])
phrase.add_token_translation("slapbox", 1, "להתאגרף במכות פתוחות", 0, similar_sound: [])

phrase = phrases[27]
phrase.add_token_translation("Let me show", 0, "תן לי להראות", 0, similar_sound: ["let me go","set me low"])
phrase.add_token_translation("you", 0, "לך", 0, similar_sound: ["do","new","through"])
phrase.add_token_translation("maintainin'", 0, "לשמור על", 0, similar_sound: ["containing","detaining"])
phrase.add_token_translation("this shit", 0, "החרא הזה", 0, similar_sound: ["this fit","miss hit"])
phrase.add_token_translation("ain't", 0, "זה לא", 0, similar_sound: ["paint","faint"])
phrase.add_token_translation("that hard", 0, "כל כך קשה", 0, similar_sound: ["fat card","bad guard"])
phrase.add_token_translation("that hard", 1, "כל כך קשה", 1, similar_sound: ["fat card","bad guard"])

phrase = phrases[28]
phrase.add_token_translation("Everybody", 0, "כולם", 0, similar_sound: [])
phrase.add_token_translation("wants", 0, "רוצים", 0, similar_sound: [])
phrase.add_token_translation("the key", 0, "את המפתח", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ואת", 0, similar_sound: [])
phrase.add_token_translation("the secret", 0, "הסוד", 0, similar_sound: [])
phrase.add_token_translation("to", 0, "ל", 0, similar_sound: [])
phrase.add_token_translation("rap", 0, "ראפ", 0, similar_sound: [])
phrase.add_token_translation("immortality", 0, "אלמוות", 0, similar_sound: [])
phrase.add_token_translation("like", 0, "כמו", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "שאני", 0, similar_sound: [])
phrase.add_token_translation("have got", 0, "השגתי", 0, similar_sound: [])

phrase = phrases[29]
phrase.add_token_translation("Well,", 0, "ובכן,", 0, similar_sound: [])
phrase.add_token_translation("they be", 0, "הם", 0, similar_sound: [])
phrase.add_token_translation("truthfully,", 0, "באמת,", 0, similar_sound: [])
phrase.add_token_translation("the blueprint,", 0, "התוכנית,", 0, similar_sound: [])
phrase.add_token_translation("they be", 1, "הם", 1, similar_sound: [])
phrase.add_token_translation("pagan,", 0, "פגאנים,", 0, similar_sound: [])
phrase.add_token_translation("you be", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("the exuberance.", 0, "השפע.", 0, similar_sound: [])

phrase = phrases[30]
phrase.add_token_translation("Everybody", 0, "כולם", 0, similar_sound: [])
phrase.add_token_translation("loves", 0, "אוהבים", 0, similar_sound: [])
phrase.add_token_translation("the rude", 0, "את הגסות", 0, similar_sound: [])
phrase.add_token_translation("from a nuisance", 0, "ממטרד", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("earth", 0, "כדור הארץ", 0, similar_sound: [])
phrase.add_token_translation("like an asteroid", 0, "כמו אסטרואיד", 0, similar_sound: [])
phrase.add_token_translation("hitting", 0, "פוגע", 0, similar_sound: [])

phrase = phrases[31]
phrase.add_token_translation("Nothin' but", 0, "רק", 0, similar_sound: [])
phrase.add_token_translation("truth", 0, "אמת", 0, similar_sound: ["tooth","ruth"])
phrase.add_token_translation("for the moon", 0, "לירח", 0, similar_sound: [])
phrase.add_token_translation("since", 0, "מאז ש", 0, similar_sound: ["sins","sense"])
phrase.add_token_translation("MC's", 0, "אמ.סיז", 0, similar_sound: [])
phrase.add_token_translation("get taken to school", 0, "מקבלים שיעור", 0, similar_sound: [])
phrase.add_token_translation("with this music", 0, "עם המוזיקה הזו", 0, similar_sound: [])
phrase.add_token_translation("'cause", 0, "כי", 0, similar_sound: [])
phrase.add_token_translation("I use it", 0, "אני משתמש בה", 0, similar_sound: [])

phrase = phrases[32]
phrase.add_token_translation("As a vehicle", 0, "בתור כלי", 0, similar_sound: [])
phrase.add_token_translation("to bust the rhyme", 0, "לשחרר את החרוז", 0, similar_sound: [])

phrase = phrases[33]
phrase.add_token_translation("Yeah", 0, "כן", 0, similar_sound: ["yay"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye"])
phrase.add_token_translation("lead", 0, "מוביל", 0, similar_sound: ["led"])
phrase.add_token_translation("a new school", 0, "בית ספר חדש", 0, similar_sound: ["a knew school"])
phrase.add_token_translation("full of", 0, "מלא ב", 0, similar_sound: ["fool of"])
phrase.add_token_translation("students", 0, "תלמידים", 0, similar_sound: [])

phrase = phrases[34]
phrase.add_token_translation("Me", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 1, similar_sound: [])
phrase.add_token_translation("a product of", 0, "תוצר של", 0, similar_sound: [])
phrase.add_token_translation("Rakim", 0, "ראקים", 0, similar_sound: [])
phrase.add_token_translation("Lakim Shabazz", 0, "לאקים שאבאז", 0, similar_sound: [])
phrase.add_token_translation("2Pac", 0, "טופאק", 0, similar_sound: [])
phrase.add_token_translation("N.W.A.", 0, "אן.דאבליו.איי", 0, similar_sound: [])

phrase = phrases[35]
phrase.add_token_translation("Cube", 0, "קיוּב", 0, similar_sound: ["tube","boob"])
phrase.add_token_translation("Hey Doc", 0, "היי דוק", 0, similar_sound: ["haydock","redock"])
phrase.add_token_translation("Ren", 0, "רן", 0, similar_sound: ["wren","run"])
phrase.add_token_translation("Yella", 0, "ילה", 0, similar_sound: ["fella","smella"])
phrase.add_token_translation("Eazy", 0, "איזי", 0, similar_sound: ["easy","queasy"])
phrase.add_token_translation("thank you", 0, "תודה לכם", 0, similar_sound: ["think you","tank you"])
phrase.add_token_translation("they", 0, "הם", 0, similar_sound: ["day","weigh"])
phrase.add_token_translation("got", 0, "קיבלו", 0, similar_sound: ["hot","pot"])
phrase.add_token_translation("Slim", 0, "סלים", 0, similar_sound: ["swim","limb"])

phrase = phrases[36]
phrase.add_token_translation("Inspired enough", 0, "מספיק השראה", 0, similar_sound: ["aspired enough","expired enough"])
phrase.add_token_translation("to", 0, "כדי ש", 0, similar_sound: ["too","two"])
phrase.add_token_translation("one day", 0, "יום אחד", 0, similar_sound: ["won day","fun day"])
phrase.add_token_translation("grow up", 0, "אתבגר", 0, similar_sound: ["grow out","throw up"])
phrase.add_token_translation("blow up", 0, "אתפרסם", 0, similar_sound: ["slow up","glow up"])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["end","hand"])
phrase.add_token_translation("be", 0, "אהיה", 0, similar_sound: ["bee","by"])
phrase.add_token_translation("in a position", 0, "בעמדה", 0, similar_sound: ["in opposition","in a condition"])

phrase = phrases[37]
phrase.add_token_translation("To meet", 0, "לפגוש", 0, similar_sound: [])
phrase.add_token_translation("Run DMC", 0, "ראן די.אם.סי", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("induct", 0, "להכניס", 0, similar_sound: [])
phrase.add_token_translation("them", 0, "אותם", 0, similar_sound: [])
phrase.add_token_translation("into", 0, "לתוך", 0, similar_sound: [])
phrase.add_token_translation("the", 0, "ה", 0, similar_sound: [])
phrase.add_token_translation("motherfuckin'", 0, "המזורגג", 0, similar_sound: [])
phrase.add_token_translation("rock and roll", 0, "רוק אנד רול", 0, similar_sound: [])
phrase.add_token_translation("hall of fame", 0, "היכל התהילה", 0, similar_sound: [])

phrase = phrases[38]
phrase.add_token_translation("Even though", 0, "אפילו ש", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("walk", 0, "הולך", 0, similar_sound: ["wok","talk"])
phrase.add_token_translation("in a", 0, "ב", 0, similar_sound: [])
phrase.add_token_translation("church", 0, "כנסייה", 0, similar_sound: ["search","lurch"])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("burst", 0, "מתפרץ", 0, similar_sound: ["first","thirst"])
phrase.add_token_translation("in a", 1, "ב", 1, similar_sound: [])
phrase.add_token_translation("ball", 0, "כדור", 0, similar_sound: ["call","fall"])
phrase.add_token_translation("of", 0, "של", 0, similar_sound: [])
phrase.add_token_translation("flames", 0, "להבות", 0, similar_sound: ["frames","names"])

phrase = phrases[39]
phrase.add_token_translation("Only", 0, "היחיד", 0, similar_sound: [])
phrase.add_token_translation("hall of fame", 0, "היכל התהילה", 0, similar_sound: [])
phrase.add_token_translation("I'll be inducted in", 0, "שאני אוכנס אליו", 0, similar_sound: [])
phrase.add_token_translation("is", 0, "הוא", 0, similar_sound: [])
phrase.add_token_translation("the alcohol of fame", 0, "היכל האלכוהול", 0, similar_sound: [])

phrase = phrases[40]
phrase.add_token_translation("On", 0, "על", 0, similar_sound: [])
phrase.add_token_translation("the", 0, "", -1, similar_sound: [])
phrase.add_token_translation("wall", 0, "קיר", 0, similar_sound: ["wail","wale"])
phrase.add_token_translation("of", 0, "", -1, similar_sound: [])
phrase.add_token_translation("shame", 0, "בושה", 0, similar_sound: [])

phrase = phrases[41]
phrase.add_token_translation("You", 0, "אתם", 0, similar_sound: [])
phrase.add_token_translation("fags", 0, "הומואים", 0, similar_sound: [])
phrase.add_token_translation("think", 0, "חושבים", 0, similar_sound: ["sink"])
phrase.add_token_translation("it's", 0, "זה", 0, similar_sound: ["eats"])
phrase.add_token_translation("all", 0, "הכל", 0, similar_sound: ["awl"])
phrase.add_token_translation("a game", 0, "משחק", 0, similar_sound: [])

phrase = phrases[42]
phrase.add_token_translation("Till", 0, "עד ש", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("walk", 0, "אלך", 0, similar_sound: ["talk","work"])
phrase.add_token_translation("a flock of", 0, "עם עדר של", 0, similar_sound: [])
phrase.add_token_translation("flames", 0, "להבות", 0, similar_sound: ["frames","fames"])
phrase.add_token_translation("off", 0, "מ", 0, similar_sound: ["of","cough"])
phrase.add_token_translation("a plank", 0, "קרש", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["hand","end"])
phrase.add_token_translation("tell me", 0, "תגיד לי", 0, similar_sound: [])
phrase.add_token_translation("what in the fuck", 0, "מה לעזאזל", 0, similar_sound: [])
phrase.add_token_translation("are you thinkin'", 0, "אתה חושב", 0, similar_sound: [])

phrase = phrases[43]
phrase.add_token_translation("Little", 0, "קטן", 0, similar_sound: [])
phrase.add_token_translation("gay", 0, "גיי", 0, similar_sound: ["day","say","way"])
phrase.add_token_translation("lookin'", 0, "נראה", 0, similar_sound: ["cookin'","bookin'"])
phrase.add_token_translation("boy", 0, "ילד", 0, similar_sound: ["toy","joy"])

phrase = phrases[44]
phrase.add_token_translation("So", 0, "כל כך", -1, similar_sound: [])
phrase.add_token_translation("gay", 0, "הומו", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can", 0, "יכול", 0, similar_sound: [])
phrase.add_token_translation("barely", 0, "בקושי", 0, similar_sound: [])
phrase.add_token_translation("say", 0, "לומר", 0, similar_sound: [])
phrase.add_token_translation("it", 0, "את זה", -1, similar_sound: [])
phrase.add_token_translation("with a straight face", 0, "בפנים ישרות", -1, similar_sound: [])
phrase.add_token_translation("lookin'", 0, "נראה", 0, similar_sound: [])
phrase.add_token_translation("boy", 0, "ילד", 0, similar_sound: [])

phrase = phrases[45]
phrase.add_token_translation("You", 0, "אתה", 0, similar_sound: ["yew","ewe"])
phrase.add_token_translation("witnessed", 0, "חזית", 0, similar_sound: ["witless","whiteness"])
phrase.add_token_translation("a massacre", 0, "בטבח", 0, similar_sound: ["masker","mass car"])
phrase.add_token_translation("like", 0, "כאילו", 0, similar_sound: ["light","lick"])
phrase.add_token_translation("you're watching", 0, "אתה צופה ב", 0, similar_sound: ["your watching","your wotching"])
phrase.add_token_translation("a church", 0, "כנסייה", 0, similar_sound: ["search","lurch"])
phrase.add_token_translation("gatherin'", 0, "התכנסות", 0, similar_sound: ["gathering","gatterin'"])
phrase.add_token_translation("take place", 0, "מתרחשת", 0, similar_sound: ["fake place","take base"])
phrase.add_token_translation("lookin' boy", 0, "ילדון", 0, similar_sound: ["looking boy","cookin' boy"])

phrase = phrases[46]
phrase.add_token_translation("Boy", 0, "ילד", 0, similar_sound: [])
phrase.add_token_translation("gay", 0, "הומו", 0, similar_sound: [])
phrase.add_token_translation("that", 0, "זה", 0, similar_sound: [])
phrase.add_token_translation("boy's", 0, "ילד", 1, similar_sound: [])
phrase.add_token_translation("gay", 1, "הומו", 1, similar_sound: [])
phrase.add_token_translation("that's", 0, "זה", 1, similar_sound: [])
phrase.add_token_translation("all", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("they", 0, "הם", 0, similar_sound: [])
phrase.add_token_translation("say", 0, "אומרים", 0, similar_sound: [])
phrase.add_token_translation("lookin'", 0, "נראה", 0, similar_sound: [])
phrase.add_token_translation("boy", 2, "ילד", 2, similar_sound: [])

phrase = phrases[47]
phrase.add_token_translation("You", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("get", 0, "מקבל", 0, similar_sound: [])
phrase.add_token_translation("a thumbs up", 0, "לייק", 0, similar_sound: [])
phrase.add_token_translation("pat in the back", 0, "טפיחה על השכם", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("a way to go", 0, "כל הכבוד", 0, similar_sound: [])
phrase.add_token_translation("from", 0, "מ", 0, similar_sound: [])
phrase.add_token_translation("your", 0, "שלך", 0, similar_sound: [])
phrase.add_token_translation("label", 0, "לייבל", 0, similar_sound: [])
phrase.add_token_translation("everyday", 0, "יומיומי", 0, similar_sound: [])
phrase.add_token_translation("lookin' boy", 0, "ילדון", 0, similar_sound: [])

phrase = phrases[48]
phrase.add_token_translation("Hey", 0, "היי", 0, similar_sound: [])
phrase.add_token_translation("lookin'", 0, "נראה", 0, similar_sound: ["cookin'","bookin'"])
phrase.add_token_translation("boy", 0, "ילד", 0, similar_sound: ["toy","joy"])
phrase.add_token_translation("what's", 0, "מה זה", 0, similar_sound: ["watts","lots"])
phrase.add_token_translation("a gay lookin' boy", 0, "ילד שנראה הומו", 0, similar_sound: [])

phrase = phrases[49]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("get", 0, "מקבל", 0, similar_sound: ["let","met"])
phrase.add_token_translation("a hell yeah", 0, "כן בטח", 0, similar_sound: [])
phrase.add_token_translation("from", 0, "מ", 0, similar_sound: ["form","farm"])
phrase.add_token_translation("Tray", 0, "טריי", 0, similar_sound: ["play","pray"])
phrase.add_token_translation("lookin'", 0, "שנראה כמו", 0, similar_sound: ["cookin'","hookin'"])
phrase.add_token_translation("boy", 0, "ילד", 0, similar_sound: ["toy","joy"])

phrase = phrases[50]
phrase.add_token_translation("I'mma work", 0, "אני הולך לעבוד", 0, similar_sound: [])
phrase.add_token_translation("for everything", 0, "בשביל כל מה ש", 0, similar_sound: [])
phrase.add_token_translation("I have", 0, "יש לי", 0, similar_sound: [])
phrase.add_token_translation("never asked", 0, "אף פעם לא ביקשתי", 0, similar_sound: [])
phrase.add_token_translation("nobody for shit", 0, "כלום מאף אחד", 0, similar_sound: [])
phrase.add_token_translation("get out my face", 0, "צא לי מהפרצוף", 0, similar_sound: [])
phrase.add_token_translation("lookin' boy", 0, "ילדון", 0, similar_sound: [])

phrase = phrases[51]
phrase.add_token_translation("Basically", 0, "בעצם", 0, similar_sound: [])
phrase.add_token_translation("boy", 0, "ילד", 0, similar_sound: ["toy","joy"])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: ["new","due"])
phrase.add_token_translation("never", 0, "אף פעם לא", 0, similar_sound: ["clever","lever"])
phrase.add_token_translation("gonna be capable of", 0, "תהיה מסוגל ל", 0, similar_sound: [])
phrase.add_token_translation("keepin' up with", 0, "להתמודד עם", 0, similar_sound: [])
phrase.add_token_translation("the same", 0, "אותו", 0, similar_sound: ["the game","the fame"])
phrase.add_token_translation("pace", 0, "קצב", 0, similar_sound: ["face","race"])
phrase.add_token_translation("lookin' boy", 0, "ילדון", 0, similar_sound: [])

phrase = phrases[52]
phrase.add_token_translation("'Cause", 0, "כי", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("beginnin'", 0, "מתחיל", 0, similar_sound: [])
phrase.add_token_translation("to feel", 0, "להרגיש", 0, similar_sound: [])
phrase.add_token_translation("like", 0, "כמו", 0, similar_sound: [])
phrase.add_token_translation("Rap God", 0, "ראפ גוד", 0, similar_sound: [])
phrase.add_token_translation("Rap God", 1, "ראפ גוד", 1, similar_sound: [])

phrase = phrases[53]
phrase.add_token_translation("All", 0, "כל", 0, similar_sound: [])
phrase.add_token_translation("my people", 0, "האנשים שלי", 0, similar_sound: [])
phrase.add_token_translation("from the front", 0, "מקדימה", 0, similar_sound: [])
phrase.add_token_translation("to the back", 0, "ועד אחורה", 0, similar_sound: [])
phrase.add_token_translation("nod", 0, "מהנהנים", 0, similar_sound: ["rod","cod"])
phrase.add_token_translation("back", 1, "אחורה", 1, similar_sound: ["pack","sack"])
phrase.add_token_translation("nod", 1, "מהנהנים", 1, similar_sound: ["rod","cod"])

phrase = phrases[54]
phrase.add_token_translation("The way", 0, "הדרך", 0, similar_sound: [])
phrase.add_token_translation("I'm race", 0, "אני מתחרה", 0, similar_sound: [])
phrase.add_token_translation("'round", 0, "מסביב", 0, similar_sound: [])
phrase.add_token_translation("the track", 0, "למסלול", 0, similar_sound: [])
phrase.add_token_translation("call me", 0, "תקראו לי", 0, similar_sound: [])
phrase.add_token_translation("NASCAR", 0, "נאסקר", 0, similar_sound: [])
phrase.add_token_translation("NASCAR", 1, "נאסקר", 1, similar_sound: [])

phrase = phrases[55]
phrase.add_token_translation("Dale Earnhardt", 0, "דייל ארנהרדט", 0, similar_sound: [])
phrase.add_token_translation("of", 0, "של", 0, similar_sound: [])
phrase.add_token_translation("the", 0, "ה", 0, similar_sound: [])
phrase.add_token_translation("trailer park", 0, "פארק קרוואנים", 0, similar_sound: ["trailer dark","trailer mark"])
phrase.add_token_translation("the", 1, "ה", 1, similar_sound: [])
phrase.add_token_translation("white trash", 0, "זבל לבן", 0, similar_sound: ["white crash","light trash"])
phrase.add_token_translation("god", 0, "אל", 0, similar_sound: ["cod","rod"])

phrase = phrases[56]
phrase.add_token_translation("Kneel", 0, "כרעו", 0, similar_sound: ["feel","real","meal"])
phrase.add_token_translation("before", 0, "לפני", 0, similar_sound: ["for","four","bore"])
phrase.add_token_translation("General Zod", 0, "גנרל זוד", 0, similar_sound: ["general's rod","general nod"])
phrase.add_token_translation("this planet's", 0, "הכוכב הזה הוא", 0, similar_sound: ["his planets","miss planets"])
phrase.add_token_translation("Krypton", 0, "קריפטון", 0, similar_sound: ["crypt","trip","rip"])
phrase.add_token_translation("no", 0, "לא", 0, similar_sound: ["know","mow","go"])
phrase.add_token_translation("Asgard", 0, "אסגארד", 0, similar_sound: ["ask hard","fast guard","last card"])
phrase.add_token_translation("Asgard", 1, "אסגארד", 1, similar_sound: ["ask hard","fast guard","last card"])

phrase = phrases[57]
phrase.add_token_translation("You", 0, "אתה", 0, similar_sound: ["ewe","yew"])
phrase.add_token_translation("be", 0, "תהיה", 0, similar_sound: ["bee","B"])
phrase.add_token_translation("Thor", 0, "ת'ור", 0, similar_sound: ["four","thaw"])
phrase.add_token_translation("I'll be", 0, "אני אהיה", 0, similar_sound: ["aisle bee","eye'll be"])
phrase.add_token_translation("Odin", 0, "אודין", 0, similar_sound: ["ode in"])
phrase.add_token_translation("you", 1, "אתה", 1, similar_sound: ["ewe","yew"])
phrase.add_token_translation("rodent", 0, "מכרסם", 0, similar_sound: ["rode in","roden"])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: ["aim","eye'm"])
phrase.add_token_translation("omnipotent", 0, "כל יכול", 0, similar_sound: [])

phrase = phrases[58]
phrase.add_token_translation("Let off", 0, "לירות", 0, similar_sound: ["let's cough"])
phrase.add_token_translation("then", 0, "אז", 0, similar_sound: ["den"])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: ["aim"])
phrase.add_token_translation("reloaded", 0, "נטען מחדש", 0, similar_sound: ["re-looted"])
phrase.add_token_translation("immaculately", 0, "בצורה מושלמת", 0, similar_sound: ["imaginatively"])
phrase.add_token_translation("with", 0, "עם", 0, similar_sound: ["wit"])
phrase.add_token_translation("these", 0, "אלה", 0, similar_sound: ["tease"])
phrase.add_token_translation("rhymes", 0, "חרוזים", 0, similar_sound: ["crimes"])
phrase.add_token_translation("I'm", 1, "אני", 0, similar_sound: ["aim"])
phrase.add_token_translation("totin'", 0, "נושא", 0, similar_sound: ["voting"])

phrase = phrases[59]
phrase.add_token_translation("And", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("should not be woken", 0, "לא צריך להתעורר", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 1, similar_sound: ["aim","hymn"])
phrase.add_token_translation("the", 0, "ה", 0, similar_sound: [])
phrase.add_token_translation("walking dead", 0, "מת מהלך", 0, similar_sound: [])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["bat","butt"])
phrase.add_token_translation("I'm", 1, "אני", 2, similar_sound: ["aim","hymn"])
phrase.add_token_translation("just a", 0, "רק", 0, similar_sound: [])
phrase.add_token_translation("talking head", 0, "ראש מדבר", 0, similar_sound: [])
phrase.add_token_translation("a zombie", 0, "זומבי", 0, similar_sound: [])
phrase.add_token_translation("floatin'.", 0, "צף", 0, similar_sound: ["bloating","gloating"])

phrase = phrases[60]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: ["butt","bat"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","aye"])
phrase.add_token_translation("got", 0, "גרמתי ל", 0, similar_sound: ["gut","gott"])
phrase.add_token_translation("your mom", 0, "אמא שלך", 0, similar_sound: ["your bomb","yore ma'am"])
phrase.add_token_translation("deep throatin'", 0, "לבלוע עמוק", 0, similar_sound: ["deep floating","keep boating"])

phrase = phrases[61]
phrase.add_token_translation("I'm out my ramen noodle", 0, "אני יצאתי מדעתי", 0, similar_sound: [])
phrase.add_token_translation("we", 0, "אנחנו", 0, similar_sound: [])
phrase.add_token_translation("have nothing", 0, "אין לנו", 0, similar_sound: [])
phrase.add_token_translation("in common", 0, "במשותף", 0, similar_sound: [])
phrase.add_token_translation("poodle", 0, "פודל", 0, similar_sound: ["noodle"])

phrase = phrases[62]
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("a Doberman", 0, "דוברמן", 0, similar_sound: [])
phrase.add_token_translation("pinch", 0, "צבוט", 0, similar_sound: [])
phrase.add_token_translation("yourself", 0, "את עצמך", 0, similar_sound: [])
phrase.add_token_translation("in the arm", 0, "ביד", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("pay homage", 0, "תחלוק כבוד", 0, similar_sound: [])
phrase.add_token_translation("pupil", 0, "תלמיד", 0, similar_sound: [])

phrase = phrases[63]
phrase.add_token_translation("It's", 0, "זה", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "אני", 0, similar_sound: [])

phrase = phrases[64]
phrase.add_token_translation("My", 0, "שלי", 0, similar_sound: [])
phrase.add_token_translation("honesty's", 0, "הכנות", 0, similar_sound: [])
phrase.add_token_translation("brutal", 0, "אכזרית", 0, similar_sound: [])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("it's", 0, "זה", 0, similar_sound: [])
phrase.add_token_translation("honestly", 0, "בכנות", 0, similar_sound: [])
phrase.add_token_translation("feudal", 0, "חסר תועלת", 0, similar_sound: [])
phrase.add_token_translation("if", 0, "אם", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("don't", 0, "לא", 0, similar_sound: [])
phrase.add_token_translation("utilize", 0, "אנצל", 0, similar_sound: [])
phrase.add_token_translation("what", 0, "את מה ש", 0, similar_sound: [])
phrase.add_token_translation("I", 1, "אני", 1, similar_sound: [])
phrase.add_token_translation("do", 0, "עושה", 0, similar_sound: [])
phrase.add_token_translation("though", 0, "למרות זאת", 0, similar_sound: [])

phrase = phrases[65]
phrase.add_token_translation("For good", 0, "לתמיד", 0, similar_sound: [])
phrase.add_token_translation("at least", 0, "לפחות", 0, similar_sound: [])
phrase.add_token_translation("once in a while", 0, "מדי פעם", 0, similar_sound: [])
phrase.add_token_translation("so", 0, "אז", 0, similar_sound: [])
phrase.add_token_translation("I wanna", 0, "אני רוצה", 0, similar_sound: [])
phrase.add_token_translation("make sure", 0, "לוודא", 0, similar_sound: [])
phrase.add_token_translation("somewhere", 0, "איפשהו", 0, similar_sound: [])
phrase.add_token_translation("in a", 0, "ב", 0, similar_sound: [])
phrase.add_token_translation("chicken scratch", 0, "כתב חרטומים", 0, similar_sound: [])
phrase.add_token_translation("I scribble", 0, "אני משרבט", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("doodle", 0, "מצייר", 0, similar_sound: [])

phrase = phrases[66]
phrase.add_token_translation("Enough", 0, "מספיק", 0, similar_sound: [])
phrase.add_token_translation("rhymes", 0, "חרוזים", 0, similar_sound: ["crimes","times"])
phrase.add_token_translation("maybe", 0, "אולי", 0, similar_sound: ["baby","lady"])
phrase.add_token_translation("try", 0, "לנסות", 0, similar_sound: ["cry","dry"])
phrase.add_token_translation("to help", 0, "לעזור", 0, similar_sound: ["to yelp","to kelp"])
phrase.add_token_translation("get", 0, "לעבור", 0, similar_sound: ["bet","set"])
phrase.add_token_translation("some people", 0, "כמה אנשים", 0, similar_sound: [])
phrase.add_token_translation("through", 0, "לעבור", 0, similar_sound: ["true","blue"])
phrase.add_token_translation("tough times", 0, "זמנים קשים", 0, similar_sound: [])

phrase = phrases[67]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("I gotta", 0, "אני צריך", 0, similar_sound: [])
phrase.add_token_translation("keep", 0, "לשמור", 0, similar_sound: [])
phrase.add_token_translation("a few", 0, "כמה", 0, similar_sound: [])
phrase.add_token_translation("punch lines", 0, "שורות מחץ", 0, similar_sound: [])
phrase.add_token_translation("just in case", 0, "למקרה ש", 0, similar_sound: [])
phrase.add_token_translation("'cause", 0, "כי", 0, similar_sound: [])
phrase.add_token_translation("even", 0, "אפילו", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("unsatisfied", 0, "לא מרוצה", 0, similar_sound: [])

phrase = phrases[68]
phrase.add_token_translation("Rappers", 0, "ראפרים", 0, similar_sound: [])
phrase.add_token_translation("are hungry", 0, "רעבים", 0, similar_sound: [])
phrase.add_token_translation("lookin' at", 0, "מסתכלים על", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "יי", 0, similar_sound: [])
phrase.add_token_translation("like", 0, "כאילו", 0, similar_sound: [])
phrase.add_token_translation("it's", 0, "זה", 0, similar_sound: [])
phrase.add_token_translation("lunch time", 0, "זמן ארוחת צהריים", 0, similar_sound: [])

phrase = phrases[69]
phrase.add_token_translation("I know", 0, "אני יודע", 0, similar_sound: [])
phrase.add_token_translation("there was", 0, "היה", 0, similar_sound: [])
phrase.add_token_translation("a time", 0, "זמן", 0, similar_sound: [])
phrase.add_token_translation("where", 0, "שבו", 0, similar_sound: [])
phrase.add_token_translation("once", 0, "פעם", 0, similar_sound: ["ones","wants"])
phrase.add_token_translation("I was", 0, "הייתי", 0, similar_sound: [])
phrase.add_token_translation("king", 0, "מלך", 0, similar_sound: ["sing","thing"])
phrase.add_token_translation("of the underground", 0, "המחתרת", 0, similar_sound: [])

phrase = phrases[70]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("still", 0, "עדיין", 0, similar_sound: [])
phrase.add_token_translation("rap", 0, "מראפף", 0, similar_sound: [])
phrase.add_token_translation("like", 0, "כמו", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "שאני", 0, similar_sound: [])
phrase.add_token_translation("on", 0, "ב-", 0, similar_sound: [])
phrase.add_token_translation("my", 0, "של", 0, similar_sound: [])
phrase.add_token_translation("Pharoahe Monch", 0, "פארואה מונץ'", 0, similar_sound: [])
phrase.add_token_translation("grind", 0, "גראיינד", 0, similar_sound: [])

phrase = phrases[71]
phrase.add_token_translation("So", 0, "אז", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("crunch", 0, "כותב", 0, similar_sound: [])
phrase.add_token_translation("rhymes", 0, "חרוזים", 0, similar_sound: [])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("sometimes", 0, "לפעמים", 0, similar_sound: [])
phrase.add_token_translation("when", 0, "כש", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("come back", 0, "חוזר", 0, similar_sound: [])

phrase = phrases[72]
phrase.add_token_translation("Up here", 0, "כאן למעלה", 0, similar_sound: [])
phrase.add_token_translation("with", 0, "עם", 0, similar_sound: [])
phrase.add_token_translation("the skin color", 0, "צבע העור", 0, similar_sound: [])
phrase.add_token_translation("of mine", 0, "שלי", 0, similar_sound: [])
phrase.add_token_translation("you get", 0, "אתה נהיה", 0, similar_sound: [])
phrase.add_token_translation("too big", 0, "גדול מדי", 0, similar_sound: [])
phrase.add_token_translation("and it becomes", 0, "וזה נהיה", 0, similar_sound: [])
phrase.add_token_translation("tryin'", 0, "מתיש", 0, similar_sound: [])

phrase = phrases[73]
phrase.add_token_translation("To censure", 0, "לצנזר", 0, similar_sound: ["to sensor"])
phrase.add_token_translation("you", 0, "אותך", 0, similar_sound: ["ewe"])
phrase.add_token_translation("like that", 0, "כמו אותה", 0, similar_sound: ["light that"])
phrase.add_token_translation("one line", 0, "שורה אחת", 0, similar_sound: ["won't lie"])
phrase.add_token_translation("I said", 0, "שאמרתי", 0, similar_sound: ["iced"])
phrase.add_token_translation("on", 0, "ב", 0, similar_sound: ["awn"])
phrase.add_token_translation("'I'm Back'", 0, "'אני חוזר'", 0, similar_sound: [])
phrase.add_token_translation("from", 0, "מתוך", 0, similar_sound: ["firm"])
phrase.add_token_translation("the Mathers LP 1", 0, "האלבום 'The Mathers LP 1'", 0, similar_sound: [])

phrase = phrases[74]
phrase.add_token_translation("When", 0, "כש", 0, similar_sound: ["win","whine"])
phrase.add_token_translation("I tried", 0, "ניסיתי", 0, similar_sound: ["eye tried","high tide"])
phrase.add_token_translation("to say", 0, "לומר", 0, similar_sound: ["two say","too say"])
phrase.add_token_translation("I", 1, "אני", 0, similar_sound: ["eye","hi"])
phrase.add_token_translation("take", 0, "לוקח", 0, similar_sound: ["ache","cake"])
phrase.add_token_translation("seven", 0, "שבעה", 0, similar_sound: ["heaven","leaven"])
phrase.add_token_translation("kids", 0, "ילדים", 0, similar_sound: ["kicks","lids"])
phrase.add_token_translation("from", 0, "מ", 0, similar_sound: ["farm","form"])
phrase.add_token_translation("Columbine", 0, "קולומביין", 0, similar_sound: [])

phrase = phrases[75]
phrase.add_token_translation("Put 'em", 0, "שים אותם", 0, similar_sound: [])
phrase.add_token_translation("all", 0, "כולם", 0, similar_sound: ["awl","fall"])
phrase.add_token_translation("in a line", 0, "בשורה", 0, similar_sound: ["incline","online"])
phrase.add_token_translation("add", 0, "הוסף", 0, similar_sound: ["had","sad"])
phrase.add_token_translation("an AK-47", 0, "AK-47", 0, similar_sound: [])
phrase.add_token_translation("a revolver", 0, "רבולבר", 0, similar_sound: ["revolve her","resolve her"])
phrase.add_token_translation("and", 0, "ו-", 0, similar_sound: ["end","hand"])
phrase.add_token_translation("a .9", 0, "אקדח 9 מ"מ", 0, similar_sound: ["nine","mine"])

phrase = phrases[76]
phrase.add_token_translation("See if", 0, "לראות אם", 0, similar_sound: [])
phrase.add_token_translation("I get away with it", 0, "אני אחמוק מזה", 0, similar_sound: [])
phrase.add_token_translation("now that", 0, "עכשיו כש", 0, similar_sound: [])
phrase.add_token_translation("I ain't as big as I was", 0, "אני כבר לא גדול כמו שהייתי", 0, similar_sound: [])

phrase = phrases[77]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("morphin'", 0, "משתנה", 0, similar_sound: [])
phrase.add_token_translation("into an immortal", 0, "לאלמוות", 0, similar_sound: [])
phrase.add_token_translation("comin'", 0, "עובר", 0, similar_sound: [])
phrase.add_token_translation("through", 0, "דרך", 0, similar_sound: [])
phrase.add_token_translation("the portal", 0, "הפורטל", 0, similar_sound: [])

phrase = phrases[78]
phrase.add_token_translation("You're", 0, "אתה", 0, similar_sound: ["your","yore"])
phrase.add_token_translation("stuck", 0, "תקוע", 0, similar_sound: ["stack","luck"])
phrase.add_token_translation("in a time warp", 0, "בעיוות זמן", 0, similar_sound: [])
phrase.add_token_translation("from 2004", 0, "מ-2004", 0, similar_sound: [])
phrase.add_token_translation("though", 0, "אבל", 0, similar_sound: ["throw","dough"])

phrase = phrases[79]
phrase.add_token_translation("And", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("don't know", 0, "לא יודע", 0, similar_sound: [])
phrase.add_token_translation("what", 0, "מה", 0, similar_sound: ["hot","got"])
phrase.add_token_translation("the fuck", 0, "לעזאזל", 0, similar_sound: [])
phrase.add_token_translation("that", 0, "ש", 0, similar_sound: ["bat","cat"])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: ["do","new"])
phrase.add_token_translation("rhyme", 0, "חורז", 0, similar_sound: ["time","lime"])
phrase.add_token_translation("for", 0, "למה", 0, similar_sound: ["four","door"])

phrase = phrases[80]
phrase.add_token_translation("You're", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("pointless", 0, "חסר תועלת", 0, similar_sound: [])
phrase.add_token_translation("as", 0, "כמו", 0, similar_sound: ["has"])
phrase.add_token_translation("Rapunzel", 0, "רפונזל", 0, similar_sound: [])
phrase.add_token_translation("with", 0, "עם", 0, similar_sound: ["wit"])
phrase.add_token_translation("fuckin'", 0, "מזוין", 0, similar_sound: ["bucking"])
phrase.add_token_translation("cornrows", 0, "צמות קלועות", 0, similar_sound: [])

phrase = phrases[81]
phrase.add_token_translation("You're", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("like", 0, "כמו", 0, similar_sound: [])
phrase.add_token_translation("normal", 0, "רגיל", 0, similar_sound: [])
phrase.add_token_translation("fuck", 0, "שיזדיין", 0, similar_sound: [])
phrase.add_token_translation("bein'", 0, "להיות", 0, similar_sound: [])
phrase.add_token_translation("normal", 1, "רגיל", 1, similar_sound: [])

phrase = phrases[82]
phrase.add_token_translation("And", 0, "וְ", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("just", 0, "בדיוק", 0, similar_sound: ["gist"])
phrase.add_token_translation("bought", 0, "קניתי", 0, similar_sound: ["boat"])
phrase.add_token_translation("a new", 0, "חדש", 0, similar_sound: ["knew"])
phrase.add_token_translation("ray gun", 0, "אקדח לייזר", 0, similar_sound: [])
phrase.add_token_translation("from the future", 0, "מהעתיד", 0, similar_sound: [])
phrase.add_token_translation("just", 1, "רק", 0, similar_sound: ["gist"])
phrase.add_token_translation("to come", 0, "כדי לבוא", 0, similar_sound: ["calm"])
phrase.add_token_translation("and", 1, "וְ", 1, similar_sound: [])
phrase.add_token_translation("shoot ya", 0, "לירות בך", 0, similar_sound: ["chute"])

phrase = phrases[83]
phrase.add_token_translation("Like", 0, "כמו", 0, similar_sound: ["bike","mike"])
phrase.add_token_translation("when", 0, "כש", 0, similar_sound: ["then","men"])
phrase.add_token_translation("Fabolous", 0, "פאבולוס", 0, similar_sound: [])
phrase.add_token_translation("made", 0, "עשה", 0, similar_sound: ["maid","paid"])
phrase.add_token_translation("Ray J", 0, "ריי ג'יי", 0, similar_sound: [])
phrase.add_token_translation("mad", 0, "כועס", 0, similar_sound: ["bad","had"])
phrase.add_token_translation("'cause", 0, "כי", 0, similar_sound: ["pause","laws"])
phrase.add_token_translation("Fab", 0, "פאב", 0, similar_sound: ["cab","dab"])
phrase.add_token_translation("said", 0, "אמר", 0, similar_sound: ["bed","red"])
phrase.add_token_translation("he", 0, "הוא", 0, similar_sound: ["see","me"])
phrase.add_token_translation("looked", 0, "נראה", 0, similar_sound: ["hooked","booked"])
phrase.add_token_translation("like", 1, "כמו", 1, similar_sound: ["bike","mike"])
phrase.add_token_translation("fag", 0, "הומו", 0, similar_sound: ["bag","rag"])

phrase = phrases[84]
phrase.add_token_translation("In", 0, "ב", 0, similar_sound: ["inn"])
phrase.add_token_translation("Ray J", 0, "ריי ג'יי", 0, similar_sound: [])
phrase.add_token_translation("'s", 0, "של", 0, similar_sound: ["is"])
phrase.add_token_translation("math", 0, "מתמטיקה", 0, similar_sound: ["moth"])
phrase.add_token_translation("see", 0, "לראות", 0, similar_sound: ["sea","C"])
phrase.add_token_translation("him", 0, "אותו", 0, similar_sound: ["hymn","hem"])
phrase.add_token_translation("into a man", 0, "לגבר", 0, similar_sound: [])
phrase.add_token_translation("while", 0, "בזמן ש", 0, similar_sound: ["wile"])
phrase.add_token_translation("he played", 0, "הוא שיחק", 0, similar_sound: [])
phrase.add_token_translation("Ray J", 1, "ריי ג'יי", 0, similar_sound: [])
phrase.add_token_translation("nano", 0, "ננו", 0, similar_sound: ["gnaw no"])

phrase = phrases[85]
phrase.add_token_translation("Nano", 0, "נאנו", 0, similar_sound: [])
phrase.add_token_translation("man", 0, "אחי", 0, similar_sound: ["fan","ran"])
phrase.add_token_translation("that was", 0, "זה היה", 0, similar_sound: [])
phrase.add_token_translation("a 24/7 special", 0, "שידור מיוחד 24/7", 0, similar_sound: [])
phrase.add_token_translation("on the", 0, "בערוץ", 0, similar_sound: [])
phrase.add_token_translation("cable channel", 0, "הכבלים", 0, similar_sound: [])

phrase = phrases[86]
phrase.add_token_translation("So", 0, "אז", 0, similar_sound: ["sew","sow"])
phrase.add_token_translation("Ray J", 0, "ריי ג'יי", 0, similar_sound: [])
phrase.add_token_translation("went", 0, "הלך", 0, similar_sound: ["wont"])
phrase.add_token_translation("straight", 0, "ישר", 0, similar_sound: ["strait"])
phrase.add_token_translation("to the radio station", 0, "לתחנת הרדיו", 0, similar_sound: [])
phrase.add_token_translation("the very next day", 0, "למחרת", 0, similar_sound: [])

phrase = phrases[87]
phrase.add_token_translation("Hey", 0, "היי", 0, similar_sound: [])
phrase.add_token_translation("Fab", 0, "פאב", 0, similar_sound: [])
phrase.add_token_translation("I'm gonna", 0, "אני הולך ל", 0, similar_sound: [])
phrase.add_token_translation("kill", 0, "להרוג", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אותך", 0, similar_sound: [])

phrase = phrases[88]
phrase.add_token_translation("Lyrics", 0, "מילים", 0, similar_sound: [])
phrase.add_token_translation("comin'", 0, "מגיעות", 0, similar_sound: ["common"])
phrase.add_token_translation("at you", 0, "אליך", 0, similar_sound: ["adieu"])
phrase.add_token_translation("with", 0, "ב", 0, similar_sound: ["witch"])
phrase.add_token_translation("supersonic", 0, "על-קולית", 0, similar_sound: [])
phrase.add_token_translation("speed", 0, "מהירות", 0, similar_sound: ["spade"])
phrase.add_token_translation("(J.F.K.)", 0, "(ג'.פ.ק.)", 0, similar_sound: [])

phrase = phrases[89]
phrase.add_token_translation("Summa-lumma, dooma-lumma", 0, "סומה-לומה, דומה-לומה", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: ["ewe","yew"])
phrase.add_token_translation("assumin'", 0, "מניח", 0, similar_sound: ["presuming","consuming"])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: ["aim","hymn"])
phrase.add_token_translation("a", 0, "", 0, similar_sound: ["uh","ah"])
phrase.add_token_translation("human", 0, "בן אדם", 0, similar_sound: ["humane","Hume an"])

phrase = phrases[90]
phrase.add_token_translation("What", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("I gotta do", 0, "אני צריך לעשות", 0, similar_sound: [])
phrase.add_token_translation("to get it through", 0, "כדי להעביר את זה", 0, similar_sound: [])
phrase.add_token_translation("to you", 0, "אליך", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("superhuman", 0, "על-אנושי", 0, similar_sound: [])

phrase = phrases[91]
phrase.add_token_translation("Inventin'", 0, "ממציא", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("revvin'", 0, "מאיץ", 0, similar_sound: ["heaven","seven"])
phrase.add_token_translation("and", 1, "ו", 1, similar_sound: [])
phrase.add_token_translation("I'm", 1, "אני", 1, similar_sound: [])
phrase.add_token_translation("never ever", 0, "אף פעם לא", 0, similar_sound: [])
phrase.add_token_translation("gonna", 0, "הולך", 0, similar_sound: ["gunner","honor"])
phrase.add_token_translation("be", 0, "להיות", 0, similar_sound: ["bee","sea"])
phrase.add_token_translation("relevant", 0, "רלוונטי", 0, similar_sound: ["elephant","revelant"])

phrase = phrases[92]
phrase.add_token_translation("Or", 0, "או", 0, similar_sound: ["ore","oar"])
phrase.add_token_translation("rapping", 0, "ראפ", 0, similar_sound: ["wrapping"])
phrase.add_token_translation("again", 0, "שוב", 0, similar_sound: ["a gain"])
phrase.add_token_translation("so", 0, "אז", 0, similar_sound: ["sew","sow"])
phrase.add_token_translation("anything", 0, "כל דבר", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "שאתה", 0, similar_sound: ["ewe","yew"])
phrase.add_token_translation("say", 0, "אומר", 0, similar_sound: ["sleigh","sane"])
phrase.add_token_translation("is", 0, "הוא", 0, similar_sound: ["his"])
phrase.add_token_translation("pick it stain", 0, "שלט מחאה", 0, similar_sound: ["picket sign"])

phrase = phrases[93]
phrase.add_token_translation("And", 0, "וְ", 0, similar_sound: [])
phrase.add_token_translation("I'm doing", 0, "אני עושה", 0, similar_sound: [])
phrase.add_token_translation("and", 1, "וְ", 1, similar_sound: [])
phrase.add_token_translation("I'm devastatin'", 0, "אני הורס", 0, similar_sound: [])
phrase.add_token_translation("more than ever", 0, "יותר מתמיד", 0, similar_sound: [])
phrase.add_token_translation("demonstratin'", 0, "מפגין", 0, similar_sound: ["donating","dominating"])

phrase = phrases[94]
phrase.add_token_translation("How to", 0, "איך ל", 0, similar_sound: ["now to","bow to"])
phrase.add_token_translation("give", 0, "לתת", 0, similar_sound: ["live","cave"])
phrase.add_token_translation("a motherfuckin' audience", 0, "לקהל ארור", 0, similar_sound: [])
phrase.add_token_translation("a feelin'", 0, "תחושה", 0, similar_sound: ["a ceiling","a stealing"])
phrase.add_token_translation("like it's never been felt", 0, "שמעולם לא הורגשה", 0, similar_sound: [])

phrase = phrases[95]
phrase.add_token_translation("And", 0, "וְ", 0, similar_sound: [])
phrase.add_token_translation("I know", 0, "אני יודע", 0, similar_sound: [])
phrase.add_token_translation("the haters", 0, "השונאים", 0, similar_sound: [])
phrase.add_token_translation("are forever waitin'", 0, "מחכים לנצח", 0, similar_sound: [])
phrase.add_token_translation("for the day", 0, "ליום", 0, similar_sound: [])
phrase.add_token_translation("that they can say", 0, "שיוכלו לומר", 0, similar_sound: [])
phrase.add_token_translation("I fell off", 0, "שנפלתי", 0, similar_sound: [])

phrase = phrases[96]
phrase.add_token_translation("They'll be celebratin'", 0, "הם יחגגו", 0, similar_sound: [])
phrase.add_token_translation("'cause", 0, "כי", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye"])
phrase.add_token_translation("know", 0, "יודע", 0, similar_sound: ["no"])
phrase.add_token_translation("the way", 0, "את הדרך", 0, similar_sound: ["the weigh"])
phrase.add_token_translation("to get 'em", 0, "לגרום להם", 0, similar_sound: [])
phrase.add_token_translation("motivated", 0, "להיות עם מוטיבציה", 0, similar_sound: [])

phrase = phrases[97]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("make", 0, "עושה", 0, similar_sound: [])
phrase.add_token_translation("elevatin'", 0, "מרוממת", 0, similar_sound: [])
phrase.add_token_translation("music", 0, "מוזיקה", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("make", 1, "עושה", 1, similar_sound: [])
phrase.add_token_translation("elevator", 0, "מעליות", 0, similar_sound: [])
phrase.add_token_translation("music", 1, "מוזיקה", 1, similar_sound: [])

phrase = phrases[98]
phrase.add_token_translation("Oh", 0, "אה", 0, similar_sound: [])
phrase.add_token_translation("he's", 0, "הוא", 0, similar_sound: [])
phrase.add_token_translation("too", 0, "יותר מדי", 0, similar_sound: [])
phrase.add_token_translation("mainstream", 0, "מיינסטרים", 0, similar_sound: [])
phrase.add_token_translation("Well", 0, "ובכן", 0, similar_sound: [])
phrase.add_token_translation("that's", 0, "זה", 0, similar_sound: [])
phrase.add_token_translation("what", 0, "מה", 0, similar_sound: [])
phrase.add_token_translation("they", 0, "הם", 0, similar_sound: [])
phrase.add_token_translation("do", 0, "עושים", 0, similar_sound: [])
phrase.add_token_translation("when", 0, "כש", 0, similar_sound: [])
phrase.add_token_translation("they", 1, "הם", 1, similar_sound: [])
phrase.add_token_translation("get", 0, "נהיים", 0, similar_sound: [])
phrase.add_token_translation("jealous", 0, "קנאים", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("confused", 0, "מבולבלים", 0, similar_sound: [])
phrase.add_token_translation("it", 0, "מזה", 0, similar_sound: [])

phrase = phrases[99]
phrase.add_token_translation("It's not", 0, "זה לא", 0, similar_sound: [])
phrase.add_token_translation("hip-hop", 0, "היפ הופ", 0, similar_sound: [])
phrase.add_token_translation("it's", 1, "זה", 1, similar_sound: [])
phrase.add_token_translation("pop", 0, "פופ", 0, similar_sound: [])
phrase.add_token_translation("'cause", 0, "כי", 0, similar_sound: [])
phrase.add_token_translation("I found", 0, "מצאתי", 0, similar_sound: [])
phrase.add_token_translation("a hella way", 0, "דרך מטורפת", 0, similar_sound: [])
phrase.add_token_translation("to fuse it", 0, "לשלב את זה", 0, similar_sound: [])

phrase = phrases[100]
phrase.add_token_translation("With", 0, "עם", 0, similar_sound: ["witch","whiff"])
phrase.add_token_translation("rock", 0, "רוק", 0, similar_sound: ["lock","sock"])
phrase.add_token_translation("shock-rap", 0, "שוק-ראפ", 0, similar_sound: ["sock-trap","shop-rap"])
phrase.add_token_translation("with", 1, "עם", 1, similar_sound: ["witch","whiff"])
phrase.add_token_translation("Doc", 0, "דוק", 0, similar_sound: ["dock","lock"])

phrase = phrases[101]
phrase.add_token_translation("Throw on", 0, "תפעיל", 0, similar_sound: [])
phrase.add_token_translation("Lose Yourself", 0, "Lose Yourself", 0, similar_sound: [])
phrase.add_token_translation("", 0, "", 0, similar_sound: [])
phrase.add_token_translation("I'mma", 0, "אני הולך", 0, similar_sound: [])
phrase.add_token_translation("make 'em", 0, "לגרום להם", 0, similar_sound: [])
phrase.add_token_translation("lose it", 0, "לאבד את זה", 0, similar_sound: [])
phrase.add_token_translation("", 0, "", 0, similar_sound: [])

phrase = phrases[102]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","aye"])
phrase.add_token_translation("don't know", 0, "לא יודע", 0, similar_sound: [])
phrase.add_token_translation("how to", 0, "איך ל", 0, similar_sound: [])
phrase.add_token_translation("make", 0, "ליצור", 0, similar_sound: ["ache","fake"])
phrase.add_token_translation("songs", 0, "שירים", 0, similar_sound: ["suns","strongs"])
phrase.add_token_translation("like that", 0, "כאלה", 0, similar_sound: [])

phrase = phrases[103]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","aye"])
phrase.add_token_translation("don't know", 0, "לא יודע", 0, similar_sound: [])
phrase.add_token_translation("what", 0, "אילו", 0, similar_sound: ["watt"])
phrase.add_token_translation("words", 0, "מילים", 0, similar_sound: ["wards"])
phrase.add_token_translation("to use", 0, "להשתמש", 0, similar_sound: [])

phrase = phrases[104]
phrase.add_token_translation("Lemme know", 0, "תודיע לי", 0, similar_sound: [])
phrase.add_token_translation("when", 0, "כשזה", 0, similar_sound: [])
phrase.add_token_translation("it occurs to you", 0, "יעלה לך בראש", 0, similar_sound: [])
phrase.add_token_translation("while", 0, "בזמן ש", 0, similar_sound: [])
phrase.add_token_translation("I'm rippin'", 0, "אני קורע", 0, similar_sound: [])
phrase.add_token_translation("any one of these", 0, "כל אחד מה", 0, similar_sound: [])
phrase.add_token_translation("verses", 0, "בתים", 0, similar_sound: ["curses","hearses"])
phrase.add_token_translation("the verses", 1, "הבתים", 1, similar_sound: [])
phrase.add_token_translation("you", 0, "שאתה", 0, similar_sound: ["do","through"])

phrase = phrases[105]
phrase.add_token_translation("It's curtains", 0, "זה הסוף", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("inadvertently", 0, "בלי כוונה", 0, similar_sound: [])
phrase.add_token_translation("hurtin'", 0, "פוגע", 0, similar_sound: ["certain"])
phrase.add_token_translation("you", 0, "בך", 0, similar_sound: ["dew","new"])

phrase = phrases[106]
phrase.add_token_translation("How many", 0, "כמה", 0, similar_sound: [])
phrase.add_token_translation("verses", 0, "בתים", 0, similar_sound: ["nurses","hearses"])
phrase.add_token_translation("I gotta", 0, "אני צריך ל", 0, similar_sound: ["I got a"])
phrase.add_token_translation("murder", 0, "לרצוח", 0, similar_sound: ["further"])
phrase.add_token_translation("too", 0, "גם", 0, similar_sound: ["two","to"])

phrase = phrases[107]
phrase.add_token_translation("Proof", 0, "הוכחה", 0, similar_sound: [])
phrase.add_token_translation("that", 0, "ש", 0, similar_sound: [])
phrase.add_token_translation("if", 0, "אם", 0, similar_sound: [])
phrase.add_token_translation("you were", 0, "היית", 0, similar_sound: [])
phrase.add_token_translation("half", 0, "חצי", 0, similar_sound: ["calf"])
phrase.add_token_translation("as", 0, "כמו", 0, similar_sound: ["has"])
phrase.add_token_translation("nice", 0, "נחמד", 0, similar_sound: ["knives","rice"])
phrase.add_token_translation("yo", 0, "יו", 0, similar_sound: ["go","show"])
phrase.add_token_translation("songs", 0, "שירים", 0, similar_sound: ["strongs"])
phrase.add_token_translation("you could", 0, "היית יכול", 0, similar_sound: [])
phrase.add_token_translation("sacrifice", 0, "להקריב", 0, similar_sound: ["suffice"])
phrase.add_token_translation("virgins", 0, "בתולות", 0, similar_sound: ["versions"])
phrase.add_token_translation("to", 0, "להם", 0, similar_sound: ["too","two"])

phrase = phrases[108]
phrase.add_token_translation("School", 0, "בית ספר", 0, similar_sound: ["cool","tool","rule"])
phrase.add_token_translation("flunky", 0, "כישלון", 0, similar_sound: ["funky","chunky","clunky"])
phrase.add_token_translation("pill", 0, "גלולה", 0, similar_sound: ["fill","still","will"])
phrase.add_token_translation("junkie", 0, "מכור", 0, similar_sound: ["funky","chunky","monkey"])

phrase = phrases[109]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("look at", 0, "תראה את", 0, similar_sound: [])
phrase.add_token_translation("accolades", 0, "השבחים", 0, similar_sound: [])
phrase.add_token_translation("skills", 0, "כישורים", 0, similar_sound: [])
phrase.add_token_translation("brought", 0, "הביאו", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "לי", 0, similar_sound: [])

phrase = phrases[110]
phrase.add_token_translation("Full of myself", 0, "מלא מעצמי", 0, similar_sound: ["fool of myself"])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["bat","butt"])
phrase.add_token_translation("still", 0, "עדיין", 0, similar_sound: ["steel","steal"])
phrase.add_token_translation("hungry", 0, "רעב", 0, similar_sound: ["angry","hangry"])

phrase = phrases[111]
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("bully", 0, "מתעלל", 0, similar_sound: ["fully","belly"])
phrase.add_token_translation("myself", 0, "בעצמי", 0, similar_sound: ["my shelf","by self"])
phrase.add_token_translation("'cause", 0, "כי", 0, similar_sound: ["cows","claws"])
phrase.add_token_translation("I", 1, "אני", 1, similar_sound: [])
phrase.add_token_translation("make", 0, "גורם", 0, similar_sound: ["bake","take"])
phrase.add_token_translation("me", 0, "לי", 0, similar_sound: ["knee","see"])
phrase.add_token_translation("do", 0, "לעשות", 0, similar_sound: ["dew","due"])
phrase.add_token_translation("what", 0, "מה", 0, similar_sound: ["watt","hot"])
phrase.add_token_translation("I", 2, "שאני", 0, similar_sound: [])
phrase.add_token_translation("put my mind to", 0, "מחליט", 0, similar_sound: [])

phrase = phrases[112]
phrase.add_token_translation("When", 0, "כש", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("a million", 0, "מיליון", 0, similar_sound: [])
phrase.add_token_translation("leagues", 0, "ליגות", 0, similar_sound: [])
phrase.add_token_translation("above you", 0, "מעליך", 0, similar_sound: [])

phrase = phrases[113]
phrase.add_token_translation("Ill", 0, "מטורף", 0, similar_sound: ["hill","will"])
phrase.add_token_translation("when", 0, "כש", 0, similar_sound: ["men","then"])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: ["eye","high"])
phrase.add_token_translation("speak", 0, "מדבר", 0, similar_sound: ["sneak","week"])
phrase.add_token_translation("in tongues", 0, "בלשונות", 0, similar_sound: ["in lungs","intense"])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["bat","cut"])
phrase.add_token_translation("it's", 0, "זה", 0, similar_sound: ["its","bits"])
phrase.add_token_translation("still", 0, "עדיין", 0, similar_sound: ["steel","fill"])
phrase.add_token_translation("tongue in cheek", 0, "בצחוק", 0, similar_sound: ["tongue and peak","sung in Greek"])

phrase = phrases[114]
phrase.add_token_translation("Fuck you", 0, "תזדיין", 0, similar_sound: [])
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("drunk", 0, "שיכור", 0, similar_sound: [])
phrase.add_token_translation("so", 0, "אז", 0, similar_sound: [])
phrase.add_token_translation("Satan", 0, "שטן", 0, similar_sound: [])
phrase.add_token_translation("take", 0, "קח", 0, similar_sound: [])
phrase.add_token_translation("the fuckin' wheel", 0, "ההגה המזורגג", 0, similar_sound: [])

phrase = phrases[115]
phrase.add_token_translation("I'm", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("asleep", 0, "ישן", 0, similar_sound: ["a sleep"])
phrase.add_token_translation("in the", 0, "ב", 0, similar_sound: [])
phrase.add_token_translation("front", 0, "קדמי", 0, similar_sound: ["frond"])
phrase.add_token_translation("seat", 0, "מושב", 0, similar_sound: ["sheet"])
phrase.add_token_translation("bumpin'", 0, "מנגן", 0, similar_sound: ["bumping"])
phrase.add_token_translation("heavy D", 0, "האבי די", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("the Boyz", 0, "הבויז", 0, similar_sound: ["boys"])

phrase = phrases[116]
phrase.add_token_translation("Still", 0, "עדיין", 0, similar_sound: ["steel","steal"])
phrase.add_token_translation("chunky", 0, "מגושם", 0, similar_sound: ["junkie"])
phrase.add_token_translation("but", 0, "אבל", 0, similar_sound: ["butt"])
phrase.add_token_translation("funky", 0, "פאנקי", 0, similar_sound: ["flunky"])

phrase = phrases[117]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("in my head", 0, "בראש שלי", 0, similar_sound: [])
phrase.add_token_translation("there's", 0, "יש", 0, similar_sound: ["theirs","cares"])
phrase.add_token_translation("somethin'", 0, "משהו", 0, similar_sound: [])
phrase.add_token_translation("I can feel", 0, "שאני יכול להרגיש", 0, similar_sound: [])
phrase.add_token_translation("tuggin'", 0, "מושך", 0, similar_sound: ["chugging","hugging"])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["end","hand"])
phrase.add_token_translation("strugglin'", 0, "נאבק", 0, similar_sound: ["snuggling","shrugging"])

phrase = phrases[118]
phrase.add_token_translation("Angels", 0, "מלאכים", 0, similar_sound: ["angles","angels'"])
phrase.add_token_translation("fight", 0, "נלחמים", 0, similar_sound: ["light","might","fright"])
phrase.add_token_translation("with", 0, "עם", 0, similar_sound: ["witch","wish","whiff"])
phrase.add_token_translation("devils", 0, "שדים", 0, similar_sound: ["levels","revels","dwells"])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["hand","end","sand"])
phrase.add_token_translation("here's", 0, "הנה", 0, similar_sound: ["hears","hairs","herds"])
phrase.add_token_translation("what", 0, "מה", 0, similar_sound: ["hot","got","watt"])
phrase.add_token_translation("they", 0, "הם", 0, similar_sound: ["day","way","say"])
phrase.add_token_translation("want", 0, "רוצים", 0, similar_sound: ["wont","won't","font"])
phrase.add_token_translation("from me", 0, "ממני", 0, similar_sound: ["for me","free me","from he"])

phrase = phrases[119]
phrase.add_token_translation("They're askin'", 0, "הם מבקשים", 0, similar_sound: [])
phrase.add_token_translation("me", 0, "ממני", 0, similar_sound: [])
phrase.add_token_translation("to eliminate", 0, "לחסל", 0, similar_sound: [])
phrase.add_token_translation("some of the", 0, "חלק מ", 0, similar_sound: [])
phrase.add_token_translation("women hate", 0, "שנאת נשים", 0, similar_sound: [])

phrase = phrases[120]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: ["bat","butt"])
phrase.add_token_translation("if", 0, "אם", 0, similar_sound: ["off","of"])
phrase.add_token_translation("you take into consideration", 0, "תיקח בחשבון", 0, similar_sound: [])
phrase.add_token_translation("the bitter hate", 0, "השנאה המרה", 0, similar_sound: [])
phrase.add_token_translation("that I had", 0, "שהייתה לי", 0, similar_sound: [])

phrase = phrases[121]
phrase.add_token_translation("Then", 0, "אז", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: [])
phrase.add_token_translation("may be", 0, "אולי תהיה", 0, similar_sound: [])
phrase.add_token_translation("a little", 0, "קצת", 0, similar_sound: [])
phrase.add_token_translation("patient", 0, "סבלני", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("more", 0, "יותר", 0, similar_sound: [])
phrase.add_token_translation("sympathetic", 0, "אמפתי", 0, similar_sound: [])
phrase.add_token_translation("to the situation", 0, "למצב", 0, similar_sound: [])

phrase = phrases[122]
phrase.add_token_translation("And", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("understand", 0, "להבין", 0, similar_sound: ["underhand","understated"])
phrase.add_token_translation("the", 0, "ה", 0, similar_sound: [])
phrase.add_token_translation("discrimination", 0, "אפליה", 0, similar_sound: ["disintegration","discretion"])

phrase = phrases[123]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("fuck it", 0, "שיהיה", 0, similar_sound: [])
phrase.add_token_translation("life's", 0, "החיים", 0, similar_sound: [])
phrase.add_token_translation("handing", 0, "נותנים", 0, similar_sound: [])
phrase.add_token_translation("you", 0, "לך", 0, similar_sound: [])
phrase.add_token_translation("lemons", 0, "לימונים", 0, similar_sound: [])

phrase = phrases[124]
phrase.add_token_translation("Make", 0, "תכין", 0, similar_sound: [])
phrase.add_token_translation("lemonade", 0, "לימונדה", 0, similar_sound: [])
phrase.add_token_translation("then", 0, "אז", 0, similar_sound: ["den","men","when"])

phrase = phrases[125]
phrase.add_token_translation("But", 0, "אבל", 0, similar_sound: [])
phrase.add_token_translation("if", 0, "אם", 0, similar_sound: [])
phrase.add_token_translation("I", 0, "אני", 0, similar_sound: [])
phrase.add_token_translation("can't", 0, "לא יכול", 0, similar_sound: [])
phrase.add_token_translation("batter", 0, "להכות", 0, similar_sound: ["better","butter"])
phrase.add_token_translation("the", 0, "את", 0, similar_sound: [])
phrase.add_token_translation("women", 0, "הנשים", 0, similar_sound: [])
phrase.add_token_translation("how", 0, "איך", 0, similar_sound: [])
phrase.add_token_translation("the fuck", 0, "לעזאזל", 0, similar_sound: [])
phrase.add_token_translation("am I supposed to", 0, "אני אמור", 0, similar_sound: [])
phrase.add_token_translation("bake", 0, "לאפות", 0, similar_sound: ["make","take"])
phrase.add_token_translation("them", 0, "להן", 0, similar_sound: [])
phrase.add_token_translation("a cake", 0, "עוגה", 0, similar_sound: [])
phrase.add_token_translation("then", 0, "אז", 0, similar_sound: ["den","men"])

phrase = phrases[126]
phrase.add_token_translation("Don't mistake", 0, "אל תטעו", 0, similar_sound: [])
phrase.add_token_translation("it", 0, "אותו", 0, similar_sound: ["eat","hit"])
phrase.add_token_translation("for Satan", 0, "בשטן", 0, similar_sound: ["satin","say tan"])

phrase = phrases[127]
phrase.add_token_translation("Don't mistake", 0, "אל תטעה", 0, similar_sound: [])
phrase.add_token_translation("if", 0, "אם", 0, similar_sound: ["of"])
phrase.add_token_translation("you think", 0, "אתה חושב", 0, similar_sound: [])
phrase.add_token_translation("I need", 0, "אני צריך", 0, similar_sound: [])
phrase.add_token_translation("to be", 0, "להיות", 0, similar_sound: [])
phrase.add_token_translation("overseas", 0, "בחו"ל", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: ["end"])
phrase.add_token_translation("take", 0, "לקחת", 0, similar_sound: ["ache"])
phrase.add_token_translation("a vacation", 0, "חופשה", 0, similar_sound: [])

phrase = phrases[128]
phrase.add_token_translation("To trip", 0, "לנסוע", 0, similar_sound: [])
phrase.add_token_translation("abroad", 0, "לחו"ל", 0, similar_sound: [])
phrase.add_token_translation("and", 0, "ו", 0, similar_sound: [])
phrase.add_token_translation("make", 0, "לעשות", 0, similar_sound: [])
phrase.add_token_translation("a ball", 0, "כדור", 0, similar_sound: [])
phrase.add_token_translation("of", 0, "של", 0, similar_sound: [])
phrase.add_token_translation("facial", 0, "פנים", 0, similar_sound: [])

phrase = phrases[129]
phrase.add_token_translation("Don't be", 0, "אל תהיה", 0, similar_sound: [])
phrase.add_token_translation("retard", 0, "מפגר", 0, similar_sound: [])
phrase.add_token_translation("be", 1, "תהיה", 1, similar_sound: [])
phrase.add_token_translation("king", 0, "מלך", 0, similar_sound: [])

phrase = phrases[130]
phrase.add_token_translation("Think not", 0, "אל תחשוב", 0, similar_sound: [])

phrase = phrases[131]
phrase.add_token_translation("Why", 0, "למה", 0, similar_sound: ["wry"])
phrase.add_token_translation("be a king", 0, "להיות מלך", 0, similar_sound: ["beaking"])
phrase.add_token_translation("when", 0, "כש", 0, similar_sound: ["win"])
phrase.add_token_translation("you", 0, "אתה", 0, similar_sound: ["ewe"])
phrase.add_token_translation("could be a god", 0, "יכול להיות אל", 0, similar_sound: ["could be a nod"])
