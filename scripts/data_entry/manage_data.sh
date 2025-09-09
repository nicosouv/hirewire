#!/bin/bash
# Script de gestion des données HireWire
# Usage: ./scripts/main.sh data-entry [action]

set -e

show_help() {
    echo "🎯 HireWire Data Manager"
    echo "======================="
    echo ""
    echo "AJOUT DE DONNÉES:"
    echo "  company      - Ajouter une entreprise"
    echo "  job|position - Ajouter un poste"
    echo "  process      - Ajouter un processus d'entretien"
    echo "  interview    - Ajouter un entretien individuel"
    echo "  outcome      - Ajouter un résultat"
    echo "  full         - Ajouter un entretien complet (guidé)"
    echo ""
    echo "CONSULTATION:"
    echo "  list         - Afficher toutes les données"
    echo "  stats        - Afficher les statistiques"
}

case "${1:-help}" in
    "company"|"c")
        ./scripts/data_entry/add_company.sh "${@:2}"
        ;;
    "job"|"position"|"p")
        ./scripts/data_entry/add_job_position.sh "${@:2}"
        ;;
    "process"|"proc")
        ./scripts/data_entry/add_process.sh "${@:2}"
        ;;
    "interview"|"i")
        ./scripts/data_entry/add_single_interview.sh "${@:2}"
        ;;
    "outcome"|"result"|"o")
        ./scripts/data_entry/add_outcome.sh "${@:2}"
        ;;
    "full"|"complete")
        ./scripts/data_entry/add_interview.sh
        ;;
    "list"|"l")
        ./scripts/data_entry/list_data.sh "${2:-all}"
        ;;
    "stats"|"s")
        ./scripts/data_entry/list_data.sh stats
        ;;
    "help"|"h"|*)
        show_help
        ;;
esac