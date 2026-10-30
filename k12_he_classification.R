# Shared classification/canonicalization logic for the K-12 and Higher Ed
# job-posting pipelines.
#
# Sourced from Wy_ED_Jobs.Rmd (both K-12 munge chunks and the Higher Ed munge
# chunk) so the two K-12 chunks can't drift apart, and reused verbatim by any
# one-off script that rebuilds the summary CSVs from the archived data
# (Archivek12_Data/, Archived_HE_Data/) without re-scraping. Keeping this in
# one file means "what the notebook will produce next real run" and "what a
# rebuild-from-archive script produces now" can never silently diverge.

suppressMessages(library(dplyr))

# A handful of scraped K-12 titles carry raw Windows-1252 bytes (e.g. an en
# dash in a time range like "10:00 am - 2:00 pm") that aren't valid UTF-8.
# grepl() can't validate those as UTF-8, warns "unable to translate ... to a
# wide string", and returns NA -- which case_when() treats as "no match", so
# the row silently falls through to "Other"/"Uncategorized" instead of being
# classified. Re-encoding first fixes the bad bytes.
#
# Unconditionally treating every title as Windows-1252 (this function's
# original behavior) is itself a bug: it corrupts titles that are already
# valid UTF-8 -- a genuine curly apostrophe ("Teacher's Aide") gets
# double-decoded into mojibake ("Teacherâ€™s Aide"). Only strings that
# actually fail a UTF-8 round-trip are repaired as CP1252; everything else
# passes through unchanged. Stray CRs (some sources embed raw \r) are also
# stripped here so they don't survive into archived/displayed titles.
fix_title_encoding <- function(title) {
  title <- as.character(title)
  missing <- is.na(title)
  valid_utf8 <- iconv(title, from = "UTF-8", to = "UTF-8", sub = NA_character_)
  needs_cp1252_repair <- !missing & is.na(valid_utf8)

  out <- title
  out[needs_cp1252_repair] <- iconv(
    title[needs_cp1252_repair],
    from = "WINDOWS-1252",
    to = "UTF-8",
    sub = "byte"
  )
  out <- enc2utf8(out)
  # Unescape common HTML entities that appear in scraped job titles / board text
  out <- gsub("&amp;", "&", out, fixed = TRUE)
  out <- gsub("&quot;", "\"", out, fixed = TRUE)
  out <- gsub("&#39;|&apos;", "'", out, perl = TRUE)
  out <- gsub("&lt;", "<", out, fixed = TRUE)
  out <- gsub("&gt;", ">", out, fixed = TRUE)
  out <- gsub("&nbsp;|\u00a0", " ", out, perl = TRUE)
  out <- gsub("[\r\n]+", " ", out)
  out <- trimws(out)
  out[missing] <- NA_character_
  out
}

# ---------------------------------------------------------------------------
# K-12
# ---------------------------------------------------------------------------

# Coarse position bucket from the raw job title.
classify_k12_position <- function(title) {
  title <- fix_title_encoding(title)
  dplyr::case_when(
    # Paraprofessional-related positions
    grepl("Paraprofessional|Para|Paraeducator|Teacher Assistant|Teaching Assistant|Instructional Assistant|Library Assistant|Media Assistant|Media Center Assistant", title, ignore.case = TRUE) ~ "Paraprofessional",

    # Substitute
    grepl("Sub|Substitute", title, ignore.case = TRUE) ~ "Substitute",

    # Teaching roles whose titles also carry a word claimed by an earlier
    # non-teaching rule below: ensemble "Band/Choir Director" (Administration)
    # and "Drivers Ed" (Transportation).
    grepl("\\b(Band|Choir|Choral|Orchestra|Music)\\s+Director\\b|\\bDriver'?s?\\s*Ed(ucation)?\\b|\\bTraffic Ed",
          title, ignore.case = TRUE) ~ "Teacher",

    # Support Services-related positions
    # \bIntern\b, not bare "Intern" -- matched inside "Internal Applicants Only"
    # otherwise, pulling teacher and bus-driver postings into this bucket.
    grepl("Counselor|Psychologist|Therapist|Pathologist|Occupational|Alternative Behavior Program|Audiologist|Lifeguard|Interpreter|Translator|Monitor|Safety Patrol|Social Worker|Technology Intern|Tutor|Instructional Facilitator|Resource Officer|Behavior|Occupational|Aide|Aid|Support|\\bIntern(ship)?s?\\b",
          title, ignore.case = TRUE) ~ "Support Services",

    # Staff-related positions (checked before Teacher so clerical titles like "General Secretary - Library" land here)
    grepl("Secretary|Clerk|Office Manager|Clerical|Registrar", title, ignore.case = TRUE) ~ "Staff",

    # Custodial/Maintenance-related positions
    grepl("Custodian|Custodial|Maintenance|Cleaner|Snow Removal|Facility|Electrician|HVAC",
          title, ignore.case = TRUE) ~ "Custodial/Maintenance",

    # Transportation-related positions
    # \bBus\b, not bare "Bus" -- matched inside "Business" otherwise.
    # Confirmed real impact: "Business Teacher", "Business Manager
    # Position", "Business Services Specialist/Technician" were all
    # landing in Transportation instead of their real roles.
    grepl("Bus Driver|Driver|Transportation|Route|\\bBus\\b|Mechanic|Bus Mechanic|Bus Monitor",
          title, ignore.case = TRUE) ~ "Transportation",

    # Technicians not already claimed by Custodial/Maintenance or Transportation
    # above; cafeteria technicians fall through to Food Services below.
    (grepl("Technician", title, ignore.case = TRUE) &
       !grepl("Food|Cook|Nutrition|Cafeteria|Dishwasher", title, ignore.case = TRUE)) ~ "Support Services",

    # Administration-related positions
    grepl("Principal|Director|Coordinator|Administrator|Supervisor|Administrative",
          title, ignore.case = TRUE) ~ "Administration",

    # Part-time / reduced-FTE teaching positions -- kept out of the full-FTE
    # "Teacher" bucket so they don't get counted equally with full teacher
    # postings in the subject-category trend charts.
    (grepl("Teacher|Instructor|Interventionist|English|Math|Library|Media|Language Arts|Science|Educator",
           title, ignore.case = TRUE) &
       grepl("Part[- ]?Time|Half[- ]?Time|\\b1/[2-9]th\\b|\\b0?\\.[1-9]\\s*FTE\\b",
             title, ignore.case = TRUE)) ~ "Part-Time Teacher",

    # Teacher-related positions
    grepl("Teacher|Instructor|Interventionist|English|Math|Library|Media|Language Arts|Science|Educator",
          title, ignore.case = TRUE) ~ "Teacher",

    # Coach-related positions
    # "Skiing" not bare "Ski" -- bare "Ski" matches inside "Life SKIlls".
    # Currently harmless in practice (Paraprofessional is checked earlier
    # and catches those titles first) but a real latent risk, tightened
    # defensively.
    grepl("Coach|Athletic|Sports|Track|Football|Basketball|Golf|Soccer|Wrestling|Cheer|BB|Volleyball|Aquatics|Skiing",
          title, ignore.case = TRUE) ~ "Athletics",

    # Food Services-related positions
    grepl("Food|Cook|Nutrition|Cafeteria|Dishwasher", title, ignore.case = TRUE) ~ "Food Services",

    # Student Teaching-related positions
    grepl("Daycare|After School|Head Start", title, ignore.case = TRUE) ~ "Child Care",

    # Other positions
    TRUE ~ "Other"
  )
}

# Fine-grained subject category, computed only for position == "Teacher" rows.
#
# 2026-08-04 audit: checked real title samples against the "Uncategorized"
# bucket (14.7% of all Teacher postings historically). Additions below are
# each backed by real observed titles, not speculative -- see the audit
# notes in the project's memory/commit history for the specific samples.
k12_category_keywords <- list(
  "Technical Education" = "\\b(Welding|Weld|WeldingTeacher|CTE|Automotive|Auto(?!nomy)|Wood|Woods|Woodworking|Industrial Arts|Industrial Tech|Shop|Tech Ed|Technical Education|Trade and Technical|Drivers?\\s*Ed(ucation)?|Traffic Ed|Career and Technic(i)?al)\\b",
  "Agriculture Education" = "(\\b(Agriculture|Ag Teacher|Ag Program|Agricultural teacher|FFA|Vo[-/]?Ag)\\b|\\(AG\\))",
  "Computer Science Education" = "\\b(Computer Science|Information Technology|\\bIT\\b|Technology Education(?! Teacher Assistant)|Technology Teacher)\\b",
  # Pre[- ]?school covers "Preschool"/"Pre-school"/"Pre school" in one
  # pattern; Head Start is a real, common federal early-childhood program
  # name that doesn't otherwise contain any of the other keywords here.
  "Early Childhood Education" = "\\b(Early Childhood|Pre\\s*[- ]?\\s*K(?!indergarten)|Pre\\s*[- ]?\\s*school|Birth to age|Ages 3-5|Head Start|Toddler|Daycare|Early Learning|\\bSACC\\b)\\b",
  "Elementary Education" = "\\b(Elementary|Kindergarten|1st|2nd|3rd|4th|5th|First|Second|Third|Fourth|Fifth|Grade [1-7]|Grades?\\s*K-[1-7]|K-[1-7]\\s*Teacher|Classroom Teacher|Colony Teacher|Sixth Grade|6th Grade|Seventh Grade|7th Grade|Primary Grade|Primary Teacher)\\b",
  # "Literacy/Reading Interventionist" specifically (not bare "Interventionist"
  # or "Academic Interventionist" -- those don't name a subject and are
  # genuinely ambiguous, left as Uncategorized rather than guessed).
  "English Language Arts Education" = "(?i)\\b(English(?!\\s+as\\s+a\\s+Second\\s+Language|\\s+Learner|\\s+Language\\s+Learner)|ELA|Language Arts(?!\\s*Coordinator)|(Literacy|Reading) Interventionist|Title\\s*(One|1|I)\\b|Reading Recovery|Literacy Teacher|Reading Teacher|Literacy Specialist|Reading and Writing|Intervention Teacher|Teacher Reading)\\b",
  "Family and Consumer Science" = "\\b(Family and Consumer Sciences?|FCS|Home Economics)\\b",
  "Language Education" = "\\b(ESL|ELL|English as a Second Language|English Learner|Bilingual|Spanish|French|Dual Language|World Language|Foreign Language|Arapaho|Arapahoe|Shoshone|Salish|Kootenai|Cree|Crow|Blackfeet|Cheyenne|Assiniboine|Lakota|Dakota|Native Language|Indigenous Language|Culture Teacher|\\bEL Teacher\\b|\\bELL Teacher\\b|\\bESL Teacher\\b)\\b",
  "Mathematics Education" = "\\b(Mathematics|\\bMath\\b)\\b",
  "Music Education" = "\\b(Music|Orchestra|Band|Choir|Chorus|Vocal)\\b",
  "Health Science" = "(?i)\\b(Nurse Educator|Health Science(s)? Teacher|Health Science(s)?|Certified Nursing Assistant|Nursing Assistant|CNA)\\b",
  "Science Education" = "\\b(Science|Biology|Chemistry|Physics|Earth Science)\\b",
  "Social Studies Education" = "\\b(Social Studies|History|Geography|Civics|Political Science|\\bSS Teacher\\b)\\b",
  # Special Education was the single largest category by a wide margin
  # (3,239 -- more than the next two categories combined), so it's split
  # into two here rather than left as one monolithic bucket: program types
  # that are specifically resource-room/life-skills/functional programs,
  # vs. general/core special education. Checked in that order (more
  # specific first) since a title can plausibly contain both kinds of
  # words.
  "Special Education - Resource/Life Skills" = "\\b(Resource (Teacher|Room)|Life Skills|Affective Needs|Daily Living Skills|Special Needs|\\bPALS\\b|\\bSE - TEACHER LS\\b|\\bACP\\b|Alternative Communication(s)? Program)\\b",
  "Special Education - General" = "\\b(Special[- ]Educat(i)?on|Special Ed\\.?\\b|SPED|Exceptional Children|Deaf|Visually Impaired|Autism|\\bASD\\b|\\bSE - TEACHER\\b|\\bSE TEACHER\\b|\\bSp\\.?\\s*Ed\\b|Disabilities Educator)\\b",
  "Physical Education" = "(?i)\\b(Physical Education|P\\.?E\\.?|PE\\s*/\\s*Health|Health\\s*/\\s*PE|Health and Physical Education|Phys\\.?\\s*Ed\\.?|Water Safety|Pickleball|Yoga|Aquatics|Lifeguard Instructor)\\b",
  "Business and Economics" = "\\b(Business|Economics|Econ|Financial Literacy)\\b",
  # "Guest Teacher" is a common euphemism for substitute teacher used by
  # some districts/staffing agencies (e.g. Kelly Education), not a distinct
  # role.
  "Substitute Teaching" = "(?i)\\b(Substitute Teacher|Sub Teacher|Guest Teacher(s)?)\\b",
  "Virtual Education" = "\\b(Virtual|Remote|Online)\\b",
  "Art Teacher" = "\\b(Art Teacher|\\bArt\\b|Visual Art|Pottery|Sculpture|Drawing|Ceramics|Theater|Theatre|Drama)\\b",
  "STEM Teacher" = "\\b(STEM|STEAM|Robotics)\\b",
  # JROTC/military-science instructors fold into CTE, matching how many
  # state frameworks classify JROTC.
  "CTE Teacher" = "\\b(Career and Technical Education|CTE Teacher|JROTC|ROTC|Military Instructor|Aviation Teacher)\\b",
  "Library Media" = "\\b(Library|Librarian|Media Specialist|Library Media)\\b",
  "Gifted and Talented" = "\\b(Gifted|Talented|GATE|Advanced Learning)\\b"
)

classify_k12_subject <- function(title) {
  title <- fix_title_encoding(title)
  kw <- k12_category_keywords
  dplyr::case_when(
    stringr::str_detect(title, stringr::regex(kw[["Special Education - Resource/Life Skills"]], ignore_case = TRUE)) ~ "Special Education - Resource/Life Skills",
    stringr::str_detect(title, stringr::regex(kw[["Special Education - General"]], ignore_case = TRUE)) ~ "Special Education - General",
    stringr::str_detect(title, stringr::regex(kw[["Technical Education"]], ignore_case = TRUE)) ~ "Technical Education",
    stringr::str_detect(title, stringr::regex(kw[["Agriculture Education"]], ignore_case = TRUE)) ~ "Agriculture Education",
    stringr::str_detect(title, stringr::regex(kw[["Computer Science Education"]], ignore_case = TRUE)) ~ "Computer Science Education",
    stringr::str_detect(title, stringr::regex(kw[["Early Childhood Education"]], ignore_case = TRUE)) ~ "Early Childhood Education",
    stringr::str_detect(title, stringr::regex(kw[["Elementary Education"]], ignore_case = TRUE)) ~ "Elementary Education",
    stringr::str_detect(title, stringr::regex(kw[["English Language Arts Education"]], ignore_case = TRUE)) ~ "English Language Arts Education",
    stringr::str_detect(title, stringr::regex(kw[["Family and Consumer Science"]], ignore_case = TRUE)) ~ "Family and Consumer Science",
    stringr::str_detect(title, stringr::regex(kw[["Language Education"]], ignore_case = TRUE)) ~ "Language Education",
    stringr::str_detect(title, stringr::regex(kw[["Mathematics Education"]], ignore_case = TRUE)) ~ "Mathematics Education",
    stringr::str_detect(title, stringr::regex(kw[["Music Education"]], ignore_case = TRUE)) ~ "Music Education",
    stringr::str_detect(title, stringr::regex(kw[["Physical Education"]], ignore_case = TRUE)) ~ "Physical Education",
    stringr::str_detect(title, stringr::regex(kw[["Health Science"]], ignore_case = TRUE)) ~ "Health Science",
    stringr::str_detect(title, stringr::regex(kw[["Science Education"]], ignore_case = TRUE)) ~ "Science Education",
    stringr::str_detect(title, stringr::regex(kw[["Social Studies Education"]], ignore_case = TRUE)) ~ "Social Studies Education",
    stringr::str_detect(title, stringr::regex(kw[["Business and Economics"]], ignore_case = TRUE)) ~ "Business and Economics",
    stringr::str_detect(title, stringr::regex(kw[["Substitute Teaching"]], ignore_case = TRUE)) ~ "Substitute Teaching",
    stringr::str_detect(title, stringr::regex(kw[["Virtual Education"]], ignore_case = TRUE)) ~ "Virtual Education",
    stringr::str_detect(title, stringr::regex(kw[["Art Teacher"]], ignore_case = TRUE)) ~ "Art Teacher",
    stringr::str_detect(title, stringr::regex(kw[["STEM Teacher"]], ignore_case = TRUE)) ~ "STEM Teacher",
    stringr::str_detect(title, stringr::regex(kw[["CTE Teacher"]], ignore_case = TRUE)) ~ "CTE Teacher",
    stringr::str_detect(title, stringr::regex(kw[["Library Media"]], ignore_case = TRUE)) ~ "Library Media",
    stringr::str_detect(title, stringr::regex(kw[["Gifted and Talented"]], ignore_case = TRUE)) ~ "Gifted and Talented",
    TRUE ~ "Uncategorized"
  )
}

# 2026-08-04 audit: rebalanced two oversized, artificially-merged buckets --
# "STEM" (Math + Science + generic STEM Teacher combined, 1,506 postings)
# splits into real Math/Science departments; "CTE" (7 unrelated subjects
# combined, 772 postings) splits into a trades/agriculture/technical group
# and a business/family-and-health-sciences group. Special Education's own
# split happens earlier, at the subject-category level (see
# k12_category_keywords above), and passes through unchanged here.
classify_k12_broad_category <- function(category) {
  dplyr::case_when(
    category == "Agriculture Education" ~ "CTE - Trades, Ag & Technical",
    category == "Art Teacher" ~ "Art",
    category == "Business and Economics" ~ "CTE - Business & Family Sciences",
    category == "Computer Science Education" ~ "CTE - Business & Family Sciences",
    category == "Early Childhood Education" ~ "Early Childhood",
    category == "Elementary Education" ~ "Elementary",
    category == "English Language Arts Education" ~ "English Language Arts Secondary",
    category == "Family and Consumer Science" ~ "CTE - Business & Family Sciences",
    category == "Health Science" ~ "CTE - Business & Family Sciences",
    category == "Language Education" ~ "Language",
    category == "Mathematics Education" ~ "Math",
    category == "Music Education" ~ "Music",
    category == "Physical Education" ~ "Physical Education",
    category == "STEM Teacher" ~ "Science",
    category == "Science Education" ~ "Science",
    category == "Social Studies Education" ~ "Secondary Social Studies",
    category == "Special Education - General" ~ "Special Education - General",
    category == "Special Education - Resource/Life Skills" ~ "Special Education - Resource/Life Skills",
    category == "Technical Education" ~ "CTE - Trades, Ag & Technical",
    category == "CTE Teacher" ~ "CTE - Trades, Ag & Technical",
    category == "Uncategorized" ~ "Other",
    category == "Virtual Education" ~ "Other",
    category == "Library Media" ~ "Library Media",
    category == "Gifted and Talented" ~ "Gifted and Talented",
    TRUE ~ "Other"
  )
}

# Fixes known misspellings of district names at the source so the same
# district doesn't get silently split into two "different" districts in the
# dashboard's dropdowns/trend lines.
canonicalize_k12_district <- function(district) {
  dplyr::case_when(
    district == "Hot Springs School District 1" ~ "Hot Springs County School District 1",
    district == "Crook County school District 1" ~ "Crook County School District 1",
    district == "Albany Count School District 1" ~ "Albany County School District 1",
    district == "Campbell County Scholl District 1" ~ "Campbell County School District 1",
    district == "Converse County School Distrcit 2" ~ "Converse County School District 2",
    TRUE ~ district
  )
}

# Returns a snapshot-stable K-12 posting identity. Platforms that expose a
# durable source ID supply it directly; older sources fall back to a
# normalized fingerprint of the information they do expose. Archive_Date is
# deliberately excluded so one posting keeps the same identity across weeks.
build_k12_posting_id <- function(source_id = NULL, title, location,
                                 date_posted, url, district) {
  values <- list(source_id, title, location, date_posted, url, district)
  lengths <- lengths(values)
  n <- max(c(lengths, 1L))

  recycle <- function(x) {
    if (length(x) == 0) return(rep(NA_character_, n))
    if (length(x) == 1) return(rep(as.character(x), n))
    if (length(x) != n) {
      stop("build_k12_posting_id(): inputs must have length 1 or a shared length")
    }
    as.character(x)
  }

  normalize <- function(x) {
    x <- trimws(tolower(fix_title_encoding(recycle(x))))
    x[is.na(x) | !nzchar(x)] <- "<missing>"
    x
  }

  source_id <- normalize(source_id)
  fallback <- paste(
    "fallback",
    normalize(district),
    normalize(url),
    normalize(title),
    normalize(location),
    normalize(date_posted),
    sep = "\r"
  )

  ifelse(source_id == "<missing>", fallback, source_id)
}

# Keeps the first row per posting_id. Runs right after the byte-identical
# distinct(), to catch rows that build_k12_posting_id() already treats as
# one posting but distinct() doesn't: the same source ID emitted twice with
# differing text, or fallback-keyed rows differing only in case, surrounding
# whitespace, a mis-encoded byte, or NA vs "" (all normalized away in the
# ID). Left in, those inflate k12_district_weekly_totals (a raw count()) and
# fail test-weekly-data-quality.R's posting_id-uniqueness gate, which
# blocked the 2026-09-25 weekly run. The dropped rows are written to stderr
# so the CI log shows which source produced them.
collapse_duplicate_posting_ids <- function(df, label = "K-12 postings") {
  dup <- duplicated(df$posting_id)
  if (any(dup)) {
    ids <- unique(df$posting_id[dup])
    cat(sprintf("%s: collapsing %d row(s) that share a posting_id with an earlier row:\n",
                label, sum(dup)), file = stderr())
    cat(utils::capture.output(print(df[df$posting_id %in% ids, , drop = FALSE])),
        sep = "\n", file = stderr())
  }
  df[!dup, , drop = FALSE]
}

# ---------------------------------------------------------------------------
# Higher Ed
# ---------------------------------------------------------------------------

# Coarse job-type bucket from the raw posting title. Adjunct/pooled titles
# get their own bucket, separate from "Instructor/Teacher/Faculty", so
# standing adjunct-pool postings don't get counted the same as full-time
# faculty hiring in the faculty trend charts.
classify_he_job_type <- function(title) {
  dplyr::case_when(
    # Adjunct / part-time pool positions. A bare "Part-Time" is not enough on
    # its own -- plenty of real non-faculty postings also contain that
    # phrase ("Children's Center Part-Time Aide", "Part-Time Bookstore Sales
    # Clerk"), so it only counts here alongside an actual faculty-role word.
    grepl("Adjunct", title, ignore.case = TRUE) |
      (grepl("Part[- ]?Time", title, ignore.case = TRUE) &
         grepl("Faculty|Instructor|Professor|Lecturer|Teacher", title, ignore.case = TRUE)) ~
      "Adjunct/Part-Time Faculty",

    # Administration & Faculty Affairs (checked before teaching faculty so administrative Provost roles don't land in faculty)
    grepl("Faculty Affairs|Faculty Development|Provost Office|Office of the Provost", title, ignore.case = TRUE) ~ "Administration",

    # Instructor/Teacher/Faculty
    grepl("Instructor|Instructional|Teacher|Faculty|Professor|Lecturer|Post Doc|Subject Matter Expert|Librarian|Educator", title, ignore.case = TRUE) ~ "Instructor/Teacher/Faculty",

    # Student Positions
    grepl("Student Worker|Student Position|Work Study|Students Only|Student Library Aid|Student Employment", title, ignore.case = TRUE) ~ "Student Positions",

    # Healthcare
    grepl("Nurse|Wellbeing|Health|Medicine|Medical Support Assistant", title, ignore.case = TRUE) ~ "Healthcare",

    # Temporary Position
    grepl("Pooled Position|Temporary|Monthly Pooled", title, ignore.case = TRUE) ~ "Temporary Position",

    # Staff (consolidated all office assistant/associate roles)
    grepl("Hourly|Administrative Assistant|Administrative Associate|Secretary|Library Assistant|Office Assistant|Office Associate",
          title, ignore.case = TRUE) ~ "Staff",

    # Advising (Financial Aid broadened from "Financial Aid Counselor" to
    # bare "Financial Aid" -- was previously falling through to Technical's
    # bare "Specialist" match, e.g. "Financial Aid Specialist")
    grepl("Advisor|Advising|Enrollment Counselor|Financial Aid|Night ESL Class Aide|Part-time Academic Support Services Pool- Academic Support Tutor|Peer Tutor|Tribal Education Assistant", title, ignore.case = TRUE) ~ "Advising and Student Services",

    # Culinary -- checked before Maintenance & Service so "Cook"/"Baker"
    # land here instead of being swallowed by Maintenance & Service's own
    # (now-removed) copy of the same words. Confirmed real impact: "Line
    # Cook (AM)" was landing in Maintenance & Service before this fix.
    grepl("Chef|Cook|Baker|Dining|Culinary", title, ignore.case = TRUE) ~ "Culinary",

    # Professional
    grepl("Admissions|Coordinator|Registrar|Executive Assistant|Professional|Statistician|Proctor|Exec Assistant|Exec Assistant to President|Grant Writer|Graphic Designer|Negotiator|Botanist|College Relations|Controller|Database|Officer|Auditor|Web Site|Special Assistant|Retention Mentor|Buyer Assistant|Buyer, Textbooks|GEAR UP Event & College Coordination|Ombudsperson - Office of the President|Data Analyst|Employee Relations Specialist|Finance Technician|Grant Support Specialist|Marketing & Comm Spec.|Program Specialist",
          title, ignore.case = TRUE) ~ "Professional",

    # Administration
    grepl("\\bDean\\b|Vice President|Provost|Chief|Business Manager|Enrollment Specialist|Finance Technician|HR Records Specialist", title, ignore.case = TRUE) ~ "Administration",

    # Coaching or Athletics
    grepl("coach|Athletic|Athletics", title, ignore.case = TRUE) ~ "Coaching or Athletics",

    # Accounting/Finance
    grepl("Accountant|Receivable|Accounts", title, ignore.case = TRUE) ~ "Accounting/Finance",

    # Research & Science (only actual research/scientific roles)
    grepl("Research Associate|Laboratory Technician|Research Scientist", title, ignore.case = TRUE) ~ "Research & Science",

    # Technical -- bare "Specialist" removed (it shadowed later, more
    # specific buckets like Support Services' "Library Information
    # Specialist"/"Museum Exhibit Specialist"; only qualified
    # "<Thing> Specialist" phrases stay here).
    grepl("Control Specialist|Engineer|IT Support Technician|Information Security Analyst|Programmer Analyst|Network Specialist|Data Operation Engineer|Design Engineer|GIS Specialist", title, ignore.case = TRUE) ~ "Technical",

    # Maintenance & Service ("Cook"/"Baker" removed -- see Culinary above)
    grepl("Maintenance|Technician|Facilities|Grounds|HVAC|Plumber|Carpenter|Logistics Handler|Meat Plant Technician", title, ignore.case = TRUE) ~ "Maintenance & Service",

    # Support Services
    grepl("Safety|Security|Custodian|Laborer|Driver|Cleaner|Facilities|Grounds|Library Information Specialist|Museum Exhibit Specialist|Specialist, Student Services|Campus Services I|Children's Center Part-Time Aide|KEY Camp Counselor|Lifeguard|Resident Assistant|Outdoor Recreation Lab Room|Part-Time Bookstore Sales Clerk|Physics Work-Study Assistant|Student Service Assistant|Subject Matter Expert, Life Enrichment Class",
          title, ignore.case = TRUE) ~ "Support Services",

    # Management ("Coordinator" removed -- Professional's own copy of that
    # keyword is checked earlier and always wins, making the copy here
    # dead code; confirmed real impact: 8/8 real "...Coordinator" titles
    # sampled all landed in Professional, never Management)
    grepl("Director|\\bDirector\\b|Manager|Supervisor|Assoc Director|Assoc Dir|Assist Dir|Asst Dir",
          title, ignore.case = TRUE) ~ "Management",

    TRUE ~ "Other"
  )
}

# Subject category, computed only for Job_Type == "Instructor/Teacher/Faculty" rows.
# Precedence order: Highly specific disciplines first, general catch-alls last.
classify_he_faculty_category <- function(title) {
  dplyr::case_when(
    # 1. Legal & Criminal Justice
    grepl("law|legal|college of law|attorney|juris doctor|paralegal", title, ignore.case = TRUE) ~ "Legal",
    grepl("criminal justice|criminology|law enforcement|police science|corrections|homeland security", title, ignore.case = TRUE) ~ "Criminal Justice",

    # 2. Extension / Outreach (before general agriculture/education)
    grepl("extension educator|extension specialist|\\bextension\\b|4-h", title, ignore.case = TRUE) ~ "Extension/Outreach",

    # 3. Culinary & Hospitality (before Business so Hospitality in College of Business lands here)
    grepl("culinary|hospitality|tourism|baking|food service|restaurant|hotel|brewing", title, ignore.case = TRUE) ~ "Culinary/Hospitality",

    # 4. Human Services / Social Work / Counseling (before Education / Health)
    grepl("human services?|social work|\\bmsw\\b|counseling|counselor|mental health|substance abuse|addiction|chemical dependency|\\bhdch\\b|child development|youth", title, ignore.case = TRUE) ~ "Human Services",

    # 5. CTE - Health Sciences (before general Science so "Health Sciences" lands here)
    grepl("health technology|nursing|\\brn\\b|\\blpn\\b|dental|ems|paramedic|emergency medical|emergency care|\\becp\\b|medical|medicine|nutritional|nutrition|dietetics|pharmacy|pharmacist|global health|public health|allied health|health sciences?|physician assistant|physical therapy|occupational therapy|speech-language|pathology|audiol|respiratory therapy|surgical tech|phlebotom|radiolog|x-ray|sonograph|ultrasound|biomed|clinical|medical assistant", title, ignore.case = TRUE) ~ "CTE - Health Sciences",

    # 6. Social Science (before general Science so "Political Science", "Social Sciences", "Native American Studies" land here)
    grepl("social sciences?|political science|politics|government|public policy|public administration|tribal governance|native american studies|indigenous studies|ethnic studies|african american studies|chicano|latinx|gender|sexuality|women|international relations|global studies|sociology|sociological|anthropology|psychology|psychological|behavior|geography|urban planning", title, ignore.case = TRUE) ~ "Social Science",

    # 7. Languages (including Indigenous and non-European)
    grepl("spanish|foreign language|world language|french|german|japanese|arabic|chinese|russian|italian|latin|greek|salish|kootenai|cree|crow|blackfeet|cheyenne|assiniboine|lakota|dakota|shoshone|arapaho|linguistics|\\basl\\b|sign language|\\besl\\b|\\bell\\b|tesol|language instructor", title, ignore.case = TRUE) ~ "Language",

    # 8. History
    grepl("history|historical|heritage|museum studies", title, ignore.case = TRUE) ~ "History",

    # 9. Physical Education
    grepl("physical education|\\bpe\\b|outdoor activity|outdoor recreation|recreation|athletic train|kinesiology|strength|sports management|exercise science|fitness|wellness|activity class|coach", title, ignore.case = TRUE) ~ "Physical Education",

    # 10. The Arts
    grepl("\\bart\\b|fine arts|studio art|graphic design|media arts|film|photography|animation|theater|theatre|acting|drama|stage|dance|music|band|choir|choral|orchestra|vocal|ceramics|sculpture|painting|drawing", title, ignore.case = TRUE) ~ "The Arts",

    # 11. Humanities
    grepl("humanities|philosophy|ethics|religious studies|religion|theology|literature|english|writing|composition|creative writing|communication|speech|rhetoric|journalism|broadcasting|media studies|texts and critics", title, ignore.case = TRUE) ~ "Humanities",

    # 12. Education
    grepl("education|curriculum|instructional design|educational leadership|leadership fellows|special education|sped|elementary education|secondary education|early childhood|pedagogy|teacher education|literacy education|reading education|stem education|math education|science education", title, ignore.case = TRUE) ~ "Education",

    # 13. Library
    grepl("library|librarian|archivist|information literacy", title, ignore.case = TRUE) ~ "Library",

    # 14. Mathematics
    grepl("mathematics|\\bmath\\b|calculus|algebra|geometry|statistics|actuarial|quantitative", title, ignore.case = TRUE) ~ "Math",

    # 15. CTE - Business & Computing (includes Agricultural Economics/Business)
    grepl("agricultural economics|agricultural business|computer science|computer|information technology|computing|cybersecurity|data science|software|informatics|information systems|\\bcis\\b|network|web development|artificial intelligence|\\bai\\b|machine learning|business|accounting|finance|financial planning|family financial|economics|\\becon\\b|management|marketing|commerce|entrepreneurship|\\bmba\\b|business administration|real estate|banking|\\biv&v\\b|verification & validation", title, ignore.case = TRUE) ~ "CTE - Business & Computing",

    # 16. CTE - Trades & Engineering
    grepl("agricultural communications|\\bagricultural\\b|\\bag mechanics?\\b|ag instructor|college of ag|heavy equipment|\\bheo\\b|mechanic|welding|construction|hvac|electrical|powerline|lineman|substation|diesel|automotive|auto body|\\bcdl\\b|commercial driver|truck driving|transportation|drafting|architecture|architect|aviation|pilot|flight|\\buas\\b|drone|unmanned aerial|surveying|geomatics|mining|machine tool|manufacturing|industrial|printmaking|supply chain|logistics|carpentry|plumbing|engineering|engineer|energy|equine", title, ignore.case = TRUE) ~ "CTE - Trades & Engineering",

    # 17. Science (Zoology now here; Political Science & Health Sciences safely filtered above)
    grepl("chemistry|biology|physics|astronomy|\\blab\\b|laboratory|geology|geoscience|earth science|environmental science|environmental studies|ecology|ecological|agronom|agriculture|animal science|veterinary|vet tech|plant science|soils?|hydrology|water resources|forestry|wildlife|natural resources|conservation|fisheries|range(land)? management|microbiology|biochem|neuroscience|genetics|botany|zoology|meteorology|atmospheric|\\bmsse\\b|science", title, ignore.case = TRUE) ~ "Science",

    TRUE ~ "Uncategorized"
  )
}

# Fixes the "Commmunity" (triple-m) misspelling that Eastern Wyoming
# Community College's scrape block used until it was corrected at the
# source; without this, the college's pre-2026-01-09 history and its
# current postings silently split into two different "institutions" the
# next time the full archive gets rebuilt.
canonicalize_he_institution <- function(institution) {
  dplyr::case_when(
    institution == "Eastern Wyoming Commmunity College" ~ "Eastern Wyoming Community College",
    TRUE ~ institution
  )
}
