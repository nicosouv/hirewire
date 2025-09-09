#!/bin/bash
# Ajouter une entreprise
# Usage: ./scripts/add_company.sh [nom] [secteur] [taille] [localisation] [website]

set -e

# Function to execute SQL
exec_sql() {
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "$1"
}

if [ $# -eq 0 ]; then
    # Mode interactif
    echo "📊 Ajouter une entreprise"
    echo "========================"
    read -p "Nom de l'entreprise: " name
    read -p "Secteur [Technology]: " industry
    industry=${industry:-Technology}
    read -p "Taille [100-500]: " size
    size=${size:-100-500}
    read -p "Localisation [Paris, France]: " location
    location=${location:-"Paris, France"}
    read -p "Site web (optionnel): " website
else
    # Mode commande
    name="$1"
    industry="${2:-Technology}"
    size="${3:-100-500}"
    location="${4:-Paris, France}"
    website="$5"
fi

if [[ -z "$name" ]]; then
    echo "❌ Le nom de l'entreprise est obligatoire"
    exit 1
fi

# Check if company already exists
existing_id=$(exec_sql "SELECT id FROM hirewire.companies WHERE name = '$name';" | grep -o '[0-9]\+' | head -1)

if [[ -n "$existing_id" && "$existing_id" -ne 0 ]]; then
    echo "⚠️  Entreprise '$name' existe déjà (ID: $existing_id)"
    read -p "Mettre à jour les informations ? (y/n) [n]: " update_choice
    
    if [[ "$update_choice" == "y" ]]; then
        if [[ -n "$website" ]]; then
            exec_sql "
            UPDATE hirewire.companies 
            SET industry = '$industry', size = '$size', location = '$location', website = '$website', updated_at = CURRENT_TIMESTAMP
            WHERE id = $existing_id;
            " > /dev/null
        else
            exec_sql "
            UPDATE hirewire.companies 
            SET industry = '$industry', size = '$size', location = '$location', updated_at = CURRENT_TIMESTAMP
            WHERE id = $existing_id;
            " > /dev/null
        fi
        echo "✅ Entreprise '$name' mise à jour (ID: $existing_id)"
        company_id="$existing_id"
    else
        echo "ℹ️  Utilisation de l'entreprise existante (ID: $existing_id)"
        company_id="$existing_id"
    fi
else
    # Insert new company
    if [[ -n "$website" ]]; then
        result=$(exec_sql "
        INSERT INTO hirewire.companies (name, industry, size, location, website) 
        VALUES ('$name', '$industry', '$size', '$location', '$website') 
        RETURNING id;
        ")
    else
        result=$(exec_sql "
        INSERT INTO hirewire.companies (name, industry, size, location) 
        VALUES ('$name', '$industry', '$size', '$location') 
        RETURNING id;
        ")
    fi
    
    company_id=$(echo "$result" | grep -o '[0-9]\+' | head -1)
    echo "✅ Entreprise '$name' ajoutée (ID: $company_id)"
fi

# Show usage examples
if [ $# -eq 0 ]; then
    echo ""
    echo "💡 Usage en ligne de commande:"
    echo "./scripts/add_company.sh 'TechCorp' 'Technology' '500-1000' 'Lyon, France' 'https://techcorp.fr'"
fi