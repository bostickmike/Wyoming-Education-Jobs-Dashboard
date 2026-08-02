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
# classified. Re-encoding first fixes the bad bytes; it's a no-op on titles
# that are already clean ASCII/UTF-8.
fix_title_encoding <- function(title) {
  iconv(title, from = "WINDOWS-1252", to = "UTF-8", sub = "byte")
}

# ---------------------------------------------------------------------------
# K-12
# ---------------------------------------------------------------------------

# Coarse position bucket from the raw job title.
classify_k12_position <- function(title) {
  title <- fix_title_encoding(title)
  dplyr::case_when(
    # Paraprofessional-related positions
    grepl("Paraprofessional|Para|Paraeducator", title, ignore.case = TRUE) ~ "Paraprofessional",

    # Substitute
    grepl("Sub|Substitute", title, ignore.case = TRUE) ~ "Substitute",

    # Support Services-related positions
    grepl("Counselor|Psychologist|Therapist|Pathologist|Occupational|Alternative Behavior Program|Audiologist|Lifeguard|Interpreter|Translator|Monitor|Safety Patrol|Social Worker|Technology Intern|Tutor|Instructional Facilitator|Resource Officer|Behavior|Occupational|Aide|Aid|Support",
          title, ignore.case = TRUE) ~ "Support Services",

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
    grepl("Coach|Athletic|Sports|Track|Football|Basketball|Golf|Soccer|Wrestling|Cheer|BB|Volleyball|Aquatics|Ski",
          title, ignore.case = TRUE) ~ "Athletics",

    # Custodial/Maintenance-related positions
    grepl("Custodian|Custodial|Maintenance|Cleaner|Snow Removal|Facility|Electrician|HVAC",
          title, ignore.case = TRUE) ~ "Custodial/Maintenance",

    # Transportation-related positions
    grepl("Bus Driver|Driver|Transportation|Route|Bus|Mechanic|Bus Mechanic|Bus Monitor",
          title, ignore.case = TRUE) ~ "Transportation",

    # Administration-related positions
    grepl("Principal|Director|Coordinator|Administrator|Supervisor|Administrative",
          title, ignore.case = TRUE) ~ "Administration",

    # Staff-related positions
    grepl("Secretary|Office Clerk|Office Manager|Desk Clerk|Aide", title, ignore.case = TRUE) ~ "Staff",

    # Food Services-related positions
    grepl("Food|Cook|Nutrition|Cafeteria|Dishwasher", title, ignore.case = TRUE) ~ "Food Services",

    # Student Teaching-related positions
    grepl("Daycare|After School|Head Start", title, ignore.case = TRUE) ~ "Child Care",

    # Other positions
    TRUE ~ "Other"
  )
}

# Fine-grained subject category, computed only for position == "Teacher" rows.
k12_category_keywords <- list(
  "Technical Education" = "\\b(Welding|Weld|CTE|Automotive|Auto(?!nomy)|Wood|Woods|Industrial Arts|Shop)\\b",
  "Agriculture Education" = "\\b(Agriculture|Ag Teacher|FFA)\\b",
  "Computer Science Education" = "\\b(Computer Science|Information Technology|\\bIT\\b|Technology Education(?! Teacher Assistant))\\b",
  "Early Childhood Education" = "\\b(Early Childhood|Pre[- ]?K(?!indergarten)|Preschool|Birth to age|Ages 3-5)\\b",
  "Elementary Education" = "\\b(Elementary|Kindergarten|1st|2nd|3rd|4th|5th|First|Second|Third|Fourth|Fifth|Grade [1-6])\\b",
  "English Language Arts Education" = "(?i)\\b(English(?!\\s+as\\s+a\\s+Second\\s+Language|\\s+Learner|\\s+Language\\s+Learner)|ELA|Language Arts(?!\\s*Coordinator))\\b",
  "Family and Consumer Science" = "\\b(Family and Consumer Science|FCS|Home Economics)\\b",
  "Language Education" = "\\b(ESL|ELL|English as a Second Language|Bilingual|Spanish|French|Arapaho|Dual Language|World Language|Foreign Language)\\b",
  "Mathematics Education" = "\\b(Mathematics|\\bMath\\b)\\b",
  "Music Education" = "\\b(Music|Orchestra|Band)\\b",
  "Health Science" = "\\b(Nurse Educator|Health Science)\\b",
  "Science Education" = "\\b(Science|Biology|Chemistry|Physics|Earth Science)\\b",
  "Social Studies Education" = "\\b(Social Studies|History|Geography|Civics|Political Science)\\b",
  "Special Education" = "\\b(Resource Teacher|Special Education|SPED|Exceptional Children|Deaf|Visually Impaired)\\b",
  "Physical Education" = "(?i)\\b(Physical Education|P\\.?E\\.?|PE\\s*/\\s*Health|Health\\s*/\\s*PE|Health and Physical Education)\\b",
  "Business and Economics" = "\\b(Business|Economics|Econ)\\b",
  "Substitute Teaching" = "\\b(Substitute)\\b",
  "Virtual Education" = "\\b(Virtual|Online|Remote)\\b",
  "Art Teacher" = "\\b(Art Teacher|\\bArt\\b)\\b",
  "STEM Teacher" = "\\b(STEM)\\b",
  "CTE Teacher" = "\\b(Career and Technical Education|CTE Teacher)\\b"
)

classify_k12_subject <- function(title) {
  title <- fix_title_encoding(title)
  kw <- k12_category_keywords
  dplyr::case_when(
    stringr::str_detect(title, stringr::regex(kw[["Special Education"]], ignore_case = TRUE)) ~ "Special Education",
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
    TRUE ~ "Uncategorized"
  )
}

classify_k12_broad_category <- function(category) {
  dplyr::case_when(
    category == "Agriculture Education" ~ "CTE",
    category == "Art Teacher" ~ "Art",
    category == "Business and Economics" ~ "CTE",
    category == "Computer Science Education" ~ "CTE",
    category == "Early Childhood Education" ~ "Early Childhood",
    category == "Elementary Education" ~ "Elementary",
    category == "English Language Arts Education" ~ "English Language Arts Secondary",
    category == "Family and Consumer Science" ~ "CTE",
    category == "Health Science" ~ "CTE",
    category == "Language Education" ~ "Language",
    category == "Mathematics Education" ~ "STEM",
    category == "Music Education" ~ "Music",
    category == "Physical Education" ~ "Physical Education",
    category == "STEM Teacher" ~ "STEM",
    category == "Science Education" ~ "STEM",
    category == "Social Studies Education" ~ "Secondary Social Studies",
    category == "Special Education" ~ "Special Education",
    category == "Technical Education" ~ "CTE",
    category == "Uncategorized" ~ "Other",
    category == "Virtual Education" ~ "Other",
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

# ---------------------------------------------------------------------------
# Higher Ed
# ---------------------------------------------------------------------------

# Coarse job-type bucket from the raw posting title. Adjunct/pooled titles
# get their own bucket, separate from "Instructor/Teacher/Faculty", so
# standing adjunct-pool postings don't get counted the same as full-time
# faculty hiring in the faculty trend charts.
classify_he_job_type <- function(title) {
  dplyr::case_when(
    # Adjunct / part-time pool positions
    grepl("Adjunct", title, ignore.case = TRUE) ~ "Adjunct/Part-Time Faculty",

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

    # Advising
    grepl("Advisor|Advising|Enrollment Counselor|Financial Aid Counselor|Night ESL Class Aide|Part-time Academic Support Services Pool- Academic Support Tutor|Peer Tutor|Tribal Education Assistant", title, ignore.case = TRUE) ~ "Advising and Student Services",

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

    # Technical
    grepl("Control Specialist|Engineer|IT Support Technician|Information Security Analyst|Programmer Analyst|Network Specialist|Specialist|Data Operation Engineer|Design Engineer|GIS Specialist", title, ignore.case = TRUE) ~ "Technical",

    # Maintenance & Service
    grepl("Maintenance|Technician|Facilities|Grounds|HVAC|Plumber|Carpenter|Cook|Baker|Logistics Handler|Meat Plant Technician", title, ignore.case = TRUE) ~ "Maintenance & Service",

    # Support Services
    grepl("Safety|Security|Custodian|Laborer|Driver|Cleaner|Facilities|Grounds|Library Information Specialist|Museum Exhibit Specialist|Specialist, Student Services|Campus Services I|Children's Center Part-Time Aide|KEY Camp Counselor|Lifeguard|Resident Assistant|Outdoor Recreation Lab Room|Part-Time Bookstore Sales Clerk|Physics Work-Study Assistant|Student Service Assistant|Subject Matter Expert, Life Enrichment Class",
          title, ignore.case = TRUE) ~ "Support Services",

    # Culinary
    grepl("Chef|Cook|Dining", title, ignore.case = TRUE) ~ "Culinary",

    # Management
    grepl("Coordinator|Director|\\bDirector\\b|Manager|Supervisor|Assoc Director|Assoc Dir|Assist Dir|Asst Dir",
          title, ignore.case = TRUE) ~ "Management",

    TRUE ~ "Other"
  )
}

# Subject category, computed only for Job_Type == "Instructor/Teacher/Faculty" rows.
classify_he_faculty_category <- function(title) {
  dplyr::case_when(
    grepl("Law|Legal|College of Law", title, ignore.case = TRUE) ~ "Legal",
    grepl("\\bAgricultural Communications\\b|Agricultural", title, ignore.case = TRUE) ~ "CTE",
    grepl("Math", title, ignore.case = TRUE) ~ "Math",
    grepl("Philosophy|English|Communication( Studies)?|Literature|Mass Communication", title, ignore.case = TRUE) ~ "Humanities",
    grepl("\\bComputer Science\\b|Computer|Zoology|Information Technology|Computing", title, ignore.case = TRUE) ~ "CTE",
    grepl("Chemistry|Biology|Physics|Astronomy|Lab|Geology|Science|Artificial Intelligence", title, ignore.case = TRUE) ~ "Science",
    grepl("History", title, ignore.case = TRUE) ~ "History",
    grepl("Business|Accounting|Finance", title, ignore.case = TRUE) ~ "CTE",
    grepl("Physical|Outdoor Activity|Athletic Trainer|Kinesiology|Strength", title, ignore.case = TRUE) ~ "Physical Education",
    grepl("Health Technology|Nursing|Dental Hygiene|EMS|Medical|Medicine|Nutritional|Nutrition|Pharmacy", title, ignore.case = TRUE) ~ "CTE",
    grepl("Culinary|Hospitality|Tourism", title, ignore.case = TRUE) ~ "Culinary/Hospitality",
    grepl("Technology|Equine|Industrial|Electrical|Instrumentation|CDL|Massage|Criminal Justice|Maintenance|Powerline|Substation|Construction|Diesel|Heavy Equipment|Supply Chain|Machine Tool|Welding|Mechanical|Engineering|Engineer|Energy|Printmaking",
          title, ignore.case = TRUE) ~ "CTE",
    grepl("Art|Graphic Design|Theater|Theatre|Acting|Music|Ceramics", title, ignore.case = TRUE) ~ "The Arts",
    grepl("Criminal Justice", title, ignore.case = TRUE) ~ "Criminal Justice",
    grepl("Human Services|Family", title, ignore.case = TRUE) ~ "Human Services",
    grepl("Psychology|Anthropology|Sociology|Politics|Behavior|Social Work", title, ignore.case = TRUE) ~ "Social Science",
    grepl("Spanish", title, ignore.case = TRUE) ~ "Language",
    grepl("Education|Curriculum|Educational|Early Childhood", title, ignore.case = TRUE) ~ "Education",
    grepl("library|librarian", title, ignore.case = TRUE) ~ "Library",
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
