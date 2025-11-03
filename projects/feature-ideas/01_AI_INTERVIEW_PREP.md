# 🤖 Feature #1: AI-Powered Interview Prep Assistant

**Priority**: 🔥🔥🔥🔥🔥 **KILLER FEATURE**
**Effort**: 🔨🔨🔨 Medium (3-4 semaines)
**Impact**: 💥💥💥💥💥 ÉNORME
**Competitive Gap**: ✅ PERSONNE NE FAIT ÇA

---

## 🎯 Le Problème

**User Story**: *"J'ai un entretien technique chez TechCorp dans 3 jours pour un poste Senior Backend Engineer. Je ne sais pas par où commencer ma préparation. Quelles questions vont-ils me poser ? Quels sujets réviser en priorité ?"*

**Pain Points**:
- ❌ Préparation stressante et désorganisée
- ❌ Pas de guidance sur quoi réviser
- ❌ Difficile d'anticiper les questions
- ❌ Manque de confiance avant l'interview
- ❌ Oubli de réviser certains tech topics importants

**Ampleur du problème**:
- 78% des candidats trouvent la préparation d'interview stressante
- Les candidats passent en moyenne 5-10h à se préparer... sans structure
- Les questions d'interview sont souvent prévisibles si on analyse bien la JD
- L'anxiété d'interview réduit les performances de 30-40%

---

## 💡 La Solution

Un **assistant AI personnalisé** qui génère un plan de préparation complet basé sur :
- La job description
- L'historique de tes interviews passées dans cette boîte/secteur
- Les patterns de questions fréquentes (détectées dans tes notes)
- Le type d'interview (technical, behavioral, system design, etc.)

### Features Core

1. **Job Description Analysis**
   - Parse la JD et extrait:
     - Tech stack requise (langages, frameworks, outils)
     - Soft skills attendues
     - Niveau de séniorité
     - Type de projets
   - Match avec ton profil

2. **Question Generation**
   - Questions techniques basées sur la tech stack
   - Questions comportementales (STAR method)
   - Questions de system design si senior
   - Questions pièges spécifiques au domaine

3. **Flashcards Interactives**
   - Format question → réponse
   - Espacé répétition (Spaced Repetition)
   - Track ton score de maîtrise

4. **Timeline de Préparation**
   - J-7 : Vue d'ensemble + tech stack review
   - J-3 : Mock interview avec les questions probables
   - J-1 : Quick review + conseils dernière minute
   - J-0 : Checklist pré-interview

5. **Mock Interview Simulator**
   - Mode "entretien blanc" avec timer
   - Questions aléatoires from generated list
   - Auto-évaluation après chaque réponse

6. **Company Insights** (si disponible)
   - Historique de tes interviews passées chez cette boîte
   - Notes sur les interviewers précédents
   - Patterns identifiés ("Ils posent toujours des questions sur X")

---

## 🏗️ Architecture Technique

### Backend

```python
# backend/app/services/ai_interview_prep_service.py

from openai import OpenAI
from anthropic import Anthropic

class InterviewPrepService:
    def __init__(self):
        self.openai = OpenAI()
        self.anthropic = Anthropic()

    async def analyze_job_description(
        self,
        job_description: str,
        position_title: str,
        seniority_level: str
    ) -> JobAnalysis:
        """
        Analyse la JD et extrait les infos clés
        """
        prompt = f"""
        Analyze this job description for a {position_title} role:

        {job_description}

        Extract and return JSON:
        {{
            "tech_stack": [...],
            "soft_skills": [...],
            "key_responsibilities": [...],
            "interview_types": [...],
            "difficulty_level": "junior|mid|senior|staff"
        }}
        """

        response = await self.openai.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"}
        )

        return JobAnalysis.parse_raw(response.choices[0].message.content)

    async def generate_interview_questions(
        self,
        job_analysis: JobAnalysis,
        interview_type: InterviewType,
        past_interviews: List[Interview],
        count: int = 20
    ) -> List[GeneratedQuestion]:
        """
        Génère des questions probables pour l'interview
        """
        # Context from past interviews
        past_context = self._build_past_interview_context(past_interviews)

        prompt = f"""
        Generate {count} likely interview questions for:
        - Role: {job_analysis.position_title}
        - Interview type: {interview_type}
        - Tech stack: {job_analysis.tech_stack}
        - Past patterns: {past_context}

        For each question, provide:
        1. The question
        2. Difficulty level (easy/medium/hard)
        3. Category (technical/behavioral/system design)
        4. Expected answer framework
        5. Key points to cover
        6. Common pitfalls to avoid
        """

        response = await self.anthropic.messages.create(
            model="claude-3-5-sonnet-20241022",
            max_tokens=4096,
            messages=[{"role": "user", "content": prompt}]
        )

        return self._parse_questions(response.content[0].text)

    async def create_prep_timeline(
        self,
        interview_date: date,
        questions: List[GeneratedQuestion],
        user_experience: int
    ) -> PrepTimeline:
        """
        Crée un planning de préparation personnalisé
        """
        days_until = (interview_date - date.today()).days

        timeline = PrepTimeline(interview_date=interview_date)

        if days_until >= 7:
            timeline.add_phase(
                day=-7,
                title="Tech Stack Review",
                tasks=[
                    "Review core technologies",
                    "Watch key tutorials",
                    "Practice coding challenges"
                ],
                questions=questions[:5]  # Easy questions
            )

        if days_until >= 3:
            timeline.add_phase(
                day=-3,
                title="Mock Interview Practice",
                tasks=[
                    "Full mock interview (45 min)",
                    "Review behavioral questions",
                    "Practice system design"
                ],
                questions=questions[5:15]  # Medium questions
            )

        timeline.add_phase(
            day=-1,
            title="Last Minute Review",
            tasks=[
                "Quick flashcard review",
                "Read company values",
                "Prepare questions for interviewer"
            ],
            questions=questions[15:]  # Hard questions
        )

        timeline.add_phase(
            day=0,
            title="Interview Day Checklist",
            tasks=[
                "Test your equipment (camera, mic)",
                "Prepare workspace",
                "Review your elevator pitch",
                "Arrive 10 min early"
            ]
        )

        return timeline
```

### API Endpoints

```python
# backend/app/api/v1/endpoints/interview_prep.py

@router.post("/interviews/{interview_id}/prep/analyze")
async def analyze_for_prep(
    interview_id: int,
    job_description: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Analyse la job description et génère le plan de prep
    """
    interview = get_interview_or_404(db, interview_id, current_user)

    # Analyze JD
    analysis = await prep_service.analyze_job_description(
        job_description=job_description,
        position_title=interview.process.job_position.title,
        seniority_level=extract_seniority(job_description)
    )

    # Get past interviews for context
    past_interviews = get_past_interviews_for_company(
        db,
        interview.process.job_position.company_id
    )

    # Generate questions
    questions = await prep_service.generate_interview_questions(
        job_analysis=analysis,
        interview_type=interview.interview_type,
        past_interviews=past_interviews,
        count=20
    )

    # Create timeline
    timeline = await prep_service.create_prep_timeline(
        interview_date=interview.scheduled_date,
        questions=questions,
        user_experience=current_user.years_experience
    )

    # Save prep data
    prep = InterviewPrep(
        interview_id=interview_id,
        analysis=analysis,
        questions=questions,
        timeline=timeline
    )
    db.add(prep)
    db.commit()

    return {
        "prep_id": prep.id,
        "analysis": analysis,
        "questions": questions,
        "timeline": timeline
    }

@router.get("/interviews/{interview_id}/prep/flashcards")
async def get_flashcards(
    interview_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Récupère les flashcards pour révision
    """
    prep = get_prep_or_404(db, interview_id)

    flashcards = [
        {
            "id": q.id,
            "question": q.question,
            "answer_framework": q.expected_answer,
            "key_points": q.key_points,
            "difficulty": q.difficulty,
            "mastery_level": get_user_mastery(current_user.id, q.id)
        }
        for q in prep.questions
    ]

    return {"flashcards": flashcards}

@router.post("/interviews/{interview_id}/prep/mock-interview")
async def start_mock_interview(
    interview_id: int,
    duration_minutes: int = 45,
    db: Session = Depends(get_db)
):
    """
    Lance un mock interview avec timer
    """
    prep = get_prep_or_404(db, interview_id)

    # Select questions based on difficulty mix
    selected_questions = prep.questions.sample_by_difficulty(
        easy=5,
        medium=3,
        hard=2
    )

    mock = MockInterview(
        prep_id=prep.id,
        questions=selected_questions,
        duration_minutes=duration_minutes,
        started_at=datetime.utcnow()
    )
    db.add(mock)
    db.commit()

    return {
        "mock_id": mock.id,
        "questions": selected_questions,
        "time_per_question": duration_minutes // len(selected_questions)
    }
```

### Frontend

```typescript
// frontend/src/pages/InterviewPrep.tsx

interface InterviewPrepProps {
  interviewId: number;
}

export const InterviewPrepPage: React.FC<InterviewPrepProps> = ({ interviewId }) => {
  const { data: prep, isLoading } = useQuery({
    queryKey: ['interview-prep', interviewId],
    queryFn: () => api.getInterviewPrep(interviewId)
  });

  const [activeTab, setActiveTab] = useState<'timeline' | 'flashcards' | 'mock'>('timeline');

  if (isLoading) return <LoadingSpinner />;

  return (
    <div className="max-w-6xl mx-auto p-6">
      <InterviewPrepHeader interview={prep.interview} />

      <Tabs value={activeTab} onChange={setActiveTab}>
        <Tab value="timeline">📅 Prep Timeline</Tab>
        <Tab value="flashcards">🎴 Flashcards</Tab>
        <Tab value="mock">🎭 Mock Interview</Tab>
      </Tabs>

      {activeTab === 'timeline' && (
        <PrepTimeline timeline={prep.timeline} />
      )}

      {activeTab === 'flashcards' && (
        <FlashcardsReview
          flashcards={prep.flashcards}
          onMasteryUpdate={(id, level) => updateMastery(id, level)}
        />
      )}

      {activeTab === 'mock' && (
        <MockInterviewSimulator
          interviewId={interviewId}
          questions={prep.questions}
        />
      )}
    </div>
  );
};

// Flashcards component avec Spaced Repetition
const FlashcardsReview: React.FC<FlashcardsProps> = ({ flashcards }) => {
  const [currentCard, setCurrentCard] = useState(0);
  const [flipped, setFlipped] = useState(false);

  const card = flashcards[currentCard];

  return (
    <div className="flex flex-col items-center gap-6">
      <div className="text-sm text-gray-500">
        Card {currentCard + 1} of {flashcards.length}
      </div>

      <div
        className="w-full max-w-2xl h-96 perspective-1000"
        onClick={() => setFlipped(!flipped)}
      >
        <div className={`flip-card ${flipped ? 'flipped' : ''}`}>
          {/* Front */}
          <div className="flip-card-front bg-white p-8 rounded-lg shadow-lg">
            <div className="flex justify-between items-start mb-4">
              <Badge>{card.difficulty}</Badge>
              <MasteryIndicator level={card.mastery_level} />
            </div>
            <h3 className="text-2xl font-bold mb-4">{card.question}</h3>
            <p className="text-gray-500">Click to reveal answer</p>
          </div>

          {/* Back */}
          <div className="flip-card-back bg-blue-50 p-8 rounded-lg shadow-lg">
            <h4 className="font-semibold mb-2">Answer Framework:</h4>
            <p className="mb-4">{card.answer_framework}</p>

            <h4 className="font-semibold mb-2">Key Points:</h4>
            <ul className="list-disc pl-5 mb-4">
              {card.key_points.map(point => (
                <li key={point}>{point}</li>
              ))}
            </ul>

            <div className="flex gap-2 mt-6">
              <Button onClick={() => rateMastery('weak')}>😰 Need more practice</Button>
              <Button onClick={() => rateMastery('good')}>👍 Got it</Button>
              <Button onClick={() => rateMastery('easy')}>✨ Easy!</Button>
            </div>
          </div>
        </div>
      </div>

      <div className="flex gap-4">
        <Button onClick={() => setCurrentCard(Math.max(0, currentCard - 1))}>
          ← Previous
        </Button>
        <Button onClick={() => setCurrentCard(Math.min(flashcards.length - 1, currentCard + 1))}>
          Next →
        </Button>
      </div>
    </div>
  );
};
```

---

## 🗄️ Database Schema

```sql
-- Interview Prep table
CREATE TABLE interview_prep (
    id SERIAL PRIMARY KEY,
    interview_id INTEGER REFERENCES interviews(id) ON DELETE CASCADE,
    job_description TEXT NOT NULL,
    analysis JSONB NOT NULL, -- Parsed job analysis
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Generated Questions
CREATE TABLE prep_questions (
    id SERIAL PRIMARY KEY,
    prep_id INTEGER REFERENCES interview_prep(id) ON DELETE CASCADE,
    question TEXT NOT NULL,
    expected_answer TEXT,
    difficulty VARCHAR(20), -- easy, medium, hard
    category VARCHAR(50), -- technical, behavioral, system_design
    key_points JSONB,
    pitfalls JSONB,
    order_index INTEGER
);

-- User Mastery Tracking (Spaced Repetition)
CREATE TABLE question_mastery (
    user_id INTEGER REFERENCES users(id),
    question_id INTEGER REFERENCES prep_questions(id),
    mastery_level INTEGER DEFAULT 0, -- 0-5
    last_reviewed_at TIMESTAMP,
    next_review_at TIMESTAMP,
    review_count INTEGER DEFAULT 0,
    PRIMARY KEY (user_id, question_id)
);

-- Mock Interviews
CREATE TABLE mock_interviews (
    id SERIAL PRIMARY KEY,
    prep_id INTEGER REFERENCES interview_prep(id),
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    duration_minutes INTEGER,
    questions_answered INTEGER DEFAULT 0,
    total_questions INTEGER
);

-- Prep Timeline Phases
CREATE TABLE prep_timeline_phases (
    id SERIAL PRIMARY KEY,
    prep_id INTEGER REFERENCES interview_prep(id),
    day_offset INTEGER, -- -7, -3, -1, 0
    title VARCHAR(255),
    tasks JSONB,
    questions INTEGER[], -- Array of question IDs
    completed BOOLEAN DEFAULT FALSE
);
```

---

## 📊 Success Metrics

### User Engagement
- **Activation**: % d'interviews qui activent la prep AI
  - Target: > 60% des interviews avec prep activée
- **Daily Active Prep**: Utilisateurs qui reviennent quotidiennement pour réviser
  - Target: > 40% DAU pendant la semaine avant interview
- **Flashcard Completion**: % de flashcards reviewées
  - Target: > 80% completion rate

### User Satisfaction
- **Prep Confidence Score**: Self-reported confidence avant/après prep
  - Target: +2 points sur échelle 1-5
- **Interview Success Rate**: % d'interviews réussies avec prep vs sans
  - Target: +15% success rate avec prep
- **Feature NPS**: Would you recommend Interview Prep AI?
  - Target: NPS > 60

### Business Impact
- **Upgrade Trigger**: % d'users qui upgrade pour débloquer plus de preps
  - Target: 15% conversion to paid
- **Retention**: Users with prep activée vs sans
  - Target: 2x retention rate
- **Referral**: Users qui partagent leurs succès d'interview
  - Target: 20% referral rate

---

## 💰 Monetization

### Freemium Model

**Free Tier**:
- 3 interview preps / mois
- 10 questions générées par prep
- Basic flashcards

**Pro Tier** ($19/mois):
- Unlimited interview preps
- 50 questions par prep
- Advanced flashcards avec spaced repetition
- Mock interview simulator
- Company insights historique
- Priority AI generation

**Credits Model** (Alternative):
- $0 base
- $5 = 100 AI credits
- 1 prep = 20 credits
- Permet de payer à l'usage

---

## 🚀 Roadmap Implementation

### Phase 1: MVP (2 semaines)
- ✅ Job description analysis
- ✅ Question generation (20 questions)
- ✅ Basic UI pour voir les questions
- ✅ Save prep data

### Phase 2: Flashcards (1 semaine)
- ✅ Flashcard UI avec flip animation
- ✅ Mastery tracking
- ✅ Progress indicators

### Phase 3: Timeline (1 semaine)
- ✅ Prep timeline generation
- ✅ Task checklist
- ✅ Daily reminders

### Phase 4: Mock Interview (1 semaine)
- ✅ Mock interview simulator
- ✅ Timer
- ✅ Self-assessment
- ✅ Performance analytics

### Total: 4-5 semaines

---

## 🎨 UI/UX Mockups

### Prep Overview
```
┌─────────────────────────────────────────────────────────┐
│  🎯 Interview Prep: Senior Backend @ TechCorp           │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  📅 Interview in 5 days (Nov 18, 2025 - 14:00)         │
│  🎭 Type: Technical Interview (45 min)                  │
│                                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                          │
│  📊 Prep Progress: ████████░░░░ 65%                     │
│     • 13/20 flashcards mastered                         │
│     • 2/3 timeline phases completed                     │
│     • 1 mock interview done (Score: 8/10)               │
│                                                          │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│                                                          │
│  🎯 Next Action: Complete Day -3 Mock Interview         │
│  ⏰ Recommended: Spend 30 min practicing today          │
│                                                          │
│  [📅 View Timeline]  [🎴 Flashcards]  [🎭 Start Mock] │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Timeline View
```
┌─────────────────────────────────────────────────────────┐
│  📅 Prep Timeline                                        │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ✅ Day -7: Tech Stack Review              [Completed]  │
│     ✓ Review Python advanced concepts                   │
│     ✓ Practice async/await patterns                     │
│     ✓ Study PostgreSQL optimization                     │
│     Questions reviewed: 5/5 ⭐                           │
│                                                          │
│  🔄 Day -3: Mock Interview Practice         [Active]    │
│     ⬜ Full 45-min mock interview                        │
│     ✓ Review behavioral STAR responses                  │
│     ⬜ Practice system design for distributed cache     │
│     Questions reviewed: 7/10                             │
│     [▶️ Start Mock Interview]                           │
│                                                          │
│  ⏳ Day -1: Last Minute Review               [Pending]  │
│     ⬜ Quick flashcard review (20 min)                   │
│     ⬜ Read TechCorp engineering blog                    │
│     ⬜ Prepare 3 questions for interviewer               │
│                                                          │
│  📍 Day 0: Interview Day!                    [Pending]  │
│     ⬜ Equipment check (camera, mic)                     │
│     ⬜ Prepare quiet workspace                           │
│     ⬜ Review elevator pitch                             │
│     ⬜ Join 10 min early                                 │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing Strategy

### Unit Tests
```python
def test_job_description_analysis():
    jd = """
    We're looking for a Senior Backend Engineer with 5+ years of experience.
    Required: Python, FastAPI, PostgreSQL, Docker, Kubernetes.
    Nice to have: AWS, Terraform.
    """

    analysis = await prep_service.analyze_job_description(jd, "Senior Backend Engineer", "senior")

    assert "Python" in analysis.tech_stack
    assert "FastAPI" in analysis.tech_stack
    assert analysis.difficulty_level == "senior"
    assert "technical" in analysis.interview_types

def test_question_generation():
    analysis = JobAnalysis(tech_stack=["Python", "FastAPI"])
    questions = await prep_service.generate_interview_questions(analysis, "technical", [], count=10)

    assert len(questions) == 10
    assert any("Python" in q.question for q in questions)
    assert all(q.difficulty in ["easy", "medium", "hard"] for q in questions)

def test_spaced_repetition():
    # User rates card as "easy"
    update_mastery(user_id=1, question_id=123, rating="easy")

    mastery = get_mastery(user_id=1, question_id=123)
    assert mastery.mastery_level == 3
    assert mastery.next_review_at > datetime.now() + timedelta(days=3)
```

### Integration Tests
- Test OpenAI/Claude API calls avec mock responses
- Test end-to-end flow: analyze JD → generate questions → create timeline
- Test flashcard mastery algorithm

### User Acceptance Tests
- Beta test avec 10 utilisateurs avant release
- A/B test prep vs no prep sur success rate
- Feedback forms après chaque interview

---

## 🔒 Privacy & Security

### Data Handling
- **Job descriptions**: Stockées encrypted at rest
- **AI responses**: Cachées pour reduce coûts API
- **User notes**: End-to-end encrypted option
- **GDPR compliance**: Right to delete all prep data

### API Keys
- Rotate OpenAI/Claude API keys régulièrement
- Rate limiting: 10 preps/hour/user (abuse prevention)
- Cost monitoring: Alert si > $100/jour AI costs

---

## 📚 Documentation

### User Guide
- How to: "Generate your first interview prep"
- Video tutorial: "Master flashcards in 5 minutes"
- FAQ: "How many questions should I review per day?"

### Developer Docs
- API reference: `/api/v1/interview-prep`
- Prompt engineering guide
- How to add new question categories

---

## 🎉 Success Stories (Future)

> *"J'ai utilisé Interview Prep AI pour mon entretien chez Google. Les questions générées étaient spot-on - 80% des vraies questions étaient dans la liste ! J'ai décroché le poste."* — Marie, Software Engineer

> *"Le mock interview m'a aidé à gérer mon stress. Le jour J, j'étais beaucoup plus confiant."* — Thomas, Product Manager

---

## 🔮 Future Enhancements (Post-MVP)

1. **Video Mock Interview**
   - Record yourself answering
   - AI feedback on body language, speech pace
   - Filler words counter ("um", "like")

2. **Peer Mock Interviews**
   - Match avec un autre user pour pratiquer ensemble
   - Video call intégré
   - Mutual feedback

3. **Interview Question Bank Community**
   - Users peuvent uploader real questions posées
   - Crowdsourced database par compagnie
   - Glassdoor-style mais pour interview questions

4. **Post-Interview Debrief**
   - "What questions were actually asked?"
   - Compare vs predictions
   - Improve AI model over time

---

**Next Steps**:
1. Validate with 10 beta users
2. Get API keys (OpenAI + Claude)
3. Design detailed UI mockups
4. Start implementation Phase 1 (MVP)
