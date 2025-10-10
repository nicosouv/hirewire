"""
Interview Process Status Service.
Handles cascading status updates like etl_update_process_status.sh
"""
from datetime import date
from sqlalchemy.orm import Session
from app.models import InterviewProcess, Interview, InterviewOutcome


class ProcessStatusService:
    """
    Service to manage interview process status updates with cascading logic.
    Implements the same logic as etl_update_process_status.sh and etl_update_past_interview.sh
    """

    INTERVIEW_STATUS_TO_PROCESS_STATUS = {
        "scheduled": "interviewing",
        "completed": "interviewing",
        "cancelled": None,  # Don't change process status
        "rescheduled": "interviewing",
        "no_show": None,  # Don't change process status
    }

    OUTCOME_TO_PROCESS_STATUS = {
        "rejection": "rejected",
        "rejected": "rejected",
        "offer": "offer",
        "accepted": "accepted",
        "ghosted": "ghosted",
        "withdrew": "withdrew",
    }

    @staticmethod
    def update_process_status_from_interview(
        db: Session,
        interview: Interview
    ) -> InterviewProcess:
        """
        Update process status when interview status changes.

        Logic:
        - scheduled/completed → set process to 'interviewing'
        - Check if any interviews completed → keep 'interviewing'
        - If all interviews are scheduled, first one completed → 'screening'
        """
        process = db.query(InterviewProcess).filter(
            InterviewProcess.id == interview.process_id
        ).first()

        if not process:
            raise ValueError(f"Process {interview.process_id} not found")

        # Get mapping for interview status
        new_status = ProcessStatusService.INTERVIEW_STATUS_TO_PROCESS_STATUS.get(
            interview.status
        )

        if new_status:
            # Check if there are any completed interviews
            completed_count = db.query(Interview).filter(
                Interview.process_id == process.id,
                Interview.status == "completed"
            ).count()

            if completed_count > 0:
                new_status = "interviewing"
            elif interview.interview_round == 1 and interview.status == "completed":
                new_status = "screening"

            process.status = new_status
            db.add(process)
            db.commit()
            db.refresh(process)

        return process

    @staticmethod
    def update_process_status_from_outcome(
        db: Session,
        outcome: InterviewOutcome
    ) -> InterviewProcess:
        """
        Update process status when outcome is added/updated.

        Logic:
        - Maps outcome type directly to process status
        - rejection/rejected → 'rejected'
        - offer → 'offer'
        - accepted → 'accepted'
        - ghosted → 'ghosted'
        - withdrew → 'withdrew'
        """
        process = db.query(InterviewProcess).filter(
            InterviewProcess.id == outcome.process_id
        ).first()

        if not process:
            raise ValueError(f"Process {outcome.process_id} not found")

        new_status = ProcessStatusService.OUTCOME_TO_PROCESS_STATUS.get(
            outcome.outcome
        )

        if new_status:
            process.status = new_status
            db.add(process)
            db.commit()
            db.refresh(process)

        return process

    @staticmethod
    def update_past_interview_to_completed(
        db: Session,
        interview_id: int,
        actual_date: date
    ) -> Interview:
        """
        Update past scheduled interview to completed.
        Implements logic from etl_update_past_interview.sh

        Logic:
        - If interview was scheduled and actual_date is in the past
        - Set status to 'completed'
        - Update process status to 'interviewing' or 'screening'
        """
        interview = db.query(Interview).filter(
            Interview.id == interview_id
        ).first()

        if not interview:
            raise ValueError(f"Interview {interview_id} not found")

        # Only update if scheduled and date is in past
        if interview.status == "scheduled" and actual_date < date.today():
            interview.status = "completed"
            interview.actual_date = actual_date
            db.add(interview)
            db.commit()
            db.refresh(interview)

            # Cascade update to process
            ProcessStatusService.update_process_status_from_interview(db, interview)

        return interview

    @staticmethod
    def auto_update_process_status(
        db: Session,
        process_id: int
    ) -> InterviewProcess:
        """
        Automatically infer and update process status based on current state.

        Logic (priority order):
        1. If outcome exists → use outcome status
        2. If interviews completed → 'interviewing'
        3. If interviews scheduled → 'screening'
        4. Otherwise → keep 'applied'
        """
        process = db.query(InterviewProcess).filter(
            InterviewProcess.id == process_id
        ).first()

        if not process:
            raise ValueError(f"Process {process_id} not found")

        # Check for outcome (highest priority)
        outcome = db.query(InterviewOutcome).filter(
            InterviewOutcome.process_id == process_id
        ).first()

        if outcome:
            return ProcessStatusService.update_process_status_from_outcome(db, outcome)

        # Check for interviews
        interviews = db.query(Interview).filter(
            Interview.process_id == process_id
        ).all()

        if interviews:
            completed = any(i.status == "completed" for i in interviews)
            scheduled = any(i.status == "scheduled" for i in interviews)

            if completed:
                process.status = "interviewing"
            elif scheduled:
                process.status = "screening"

            db.add(process)
            db.commit()
            db.refresh(process)

        return process
