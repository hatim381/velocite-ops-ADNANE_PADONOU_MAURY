from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import (
    KeepTogether,
    Paragraph,
    PageBreak,
    Preformatted,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "output" / "pdf" / "reprise-velocite-sur-un-autre-pc.pdf"
OUTPUT.parent.mkdir(parents=True, exist_ok=True)

styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="TitleGuide", parent=styles["Title"], fontName="Helvetica-Bold",
    fontSize=23, leading=28, textColor=colors.HexColor("#12355B"), spaceAfter=10,
))
styles.add(ParagraphStyle(
    name="SubtitleGuide", parent=styles["Normal"], fontName="Helvetica",
    fontSize=11, leading=16, textColor=colors.HexColor("#456078"), spaceAfter=18,
))
styles.add(ParagraphStyle(
    name="SectionGuide", parent=styles["Heading2"], fontName="Helvetica-Bold",
    fontSize=14, leading=18, textColor=colors.HexColor("#12355B"), spaceBefore=14,
    spaceAfter=7,
))
styles.add(ParagraphStyle(
    name="BodyGuide", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=9.4, leading=13, spaceAfter=6,
))
styles.add(ParagraphStyle(
    name="SmallGuide", parent=styles["BodyText"], fontName="Helvetica",
    fontSize=8.1, leading=11, textColor=colors.HexColor("#385268"), spaceAfter=5,
))
styles.add(ParagraphStyle(
    name="CodeGuide", parent=styles["Code"], fontName="Courier",
    fontSize=7.8, leading=10.5, leftIndent=8, rightIndent=8, spaceBefore=4,
    spaceAfter=9, backColor=colors.HexColor("#F2F6F9"), borderColor=colors.HexColor("#D9E3EA"),
    borderWidth=0.5, borderPadding=7,
))
styles.add(ParagraphStyle(
    name="CalloutGuide", parent=styles["BodyText"], fontName="Helvetica-Bold",
    fontSize=9.2, leading=13, textColor=colors.HexColor("#12355B"),
    backColor=colors.HexColor("#E8F2F8"), borderColor=colors.HexColor("#85B5D3"),
    borderWidth=0.6, borderPadding=8, spaceBefore=4, spaceAfter=10,
))
styles.add(ParagraphStyle(
    name="WarningGuide", parent=styles["BodyText"], fontName="Helvetica-Bold",
    fontSize=9.2, leading=13, textColor=colors.HexColor("#6D4214"),
    backColor=colors.HexColor("#FFF3DD"), borderColor=colors.HexColor("#E6B85C"),
    borderWidth=0.6, borderPadding=8, spaceBefore=4, spaceAfter=10,
))


def p(text, style="BodyGuide"):
    return Paragraph(text, styles[style])


def code(text):
    return Preformatted(text.strip(), styles["CodeGuide"])


def header(canvas, doc):
    canvas.saveState()
    width, height = A4
    canvas.setStrokeColor(colors.HexColor("#85B5D3"))
    canvas.setLineWidth(0.7)
    canvas.line(doc.leftMargin, height - 1.35 * cm, width - doc.rightMargin, height - 1.35 * cm)
    canvas.setFont("Helvetica-Bold", 8)
    canvas.setFillColor(colors.HexColor("#12355B"))
    canvas.drawString(doc.leftMargin, height - 1.05 * cm, "VELO CITE - GUIDE DE REPRISE")
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(colors.HexColor("#456078"))
    canvas.drawRightString(width - doc.rightMargin, 0.8 * cm, f"Page {doc.page}")
    canvas.restoreState()


doc = SimpleDocTemplate(
    str(OUTPUT), pagesize=A4, rightMargin=1.65 * cm, leftMargin=1.65 * cm,
    topMargin=1.75 * cm, bottomMargin=1.45 * cm,
    title="Reprendre VeloCite sur un autre PC",
    author="VeloCite - atelier 6",
)

story = []
story.extend([
    p("Reprendre VeloCite sur un autre PC", "TitleGuide"),
    p("Guide Windows PowerShell - le depot a deja ete recupere avec Git", "SubtitleGuide"),
    p("Objectif : reconstruire le cluster Kubernetes local, les environnements dev et prod, puis deployer la version API 2.2.0 avec ses protections de production.", "CalloutGuide"),
    p("Ce que ce guide reproduit", "SectionGuide"),
    p("Le second PC obtiendra la meme architecture et la meme configuration versionnee : cluster kind, outils partages, namespaces, politiques de securite, applications, autoscaler et budgets d'interruption. Les certificats, mots de passe et donnees d'initialisation seront regeneres localement : ils ne doivent pas etre copies depuis le premier PC."),
    p("Avant de commencer", "SectionGuide"),
    p("Ouvrir PowerShell a la racine du depot. Docker Desktop doit etre demarre et disposer d'au moins 8 Go de memoire (12 Go conseilles). Si PowerShell bloque les scripts, executer une fois :"),
    code("Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"),
    p("Verifier que le depot contient bien les dernieres modifications de l'atelier 6 :"),
    code("git status\ngit log -1 --oneline"),
    p("Le repertoire de travail ne doit pas contenir de modifications inattendues avant la reprise.", "SmallGuide"),
])

story.extend([
    p("1. Installer les outils du projet", "SectionGuide"),
    p("Le script installe les versions attendues de kind, OpenTofu, kubectl et Argo. Il faut fermer puis rouvrir PowerShell apres son execution pour que le PATH soit recharge."),
    code("./scripts/installer-outils.ps1\n# Fermer puis rouvrir PowerShell dans le depot\nkind version\ntofu version\nkubectl version --client\nargo version --short"),
    p("2. Definir la phrase de chiffrement OpenTofu", "SectionGuide"),
    p("Choisir une nouvelle phrase de passe pour ce second PC et la conserver dans un gestionnaire de mots de passe. Elle chiffre les states locaux d'OpenTofu, qui contiennent des secrets. Ne jamais la committer ni l'ecrire dans un fichier du depot."),
    code('$env:TF_VAR_phrase_etat = Read-Host "Phrase du state"'),
    p("Cette variable ne vaut que pour la fenetre PowerShell ouverte. Il faut la redefinir apres ouverture d'un nouveau terminal.", "WarningGuide"),
    p("3. Liberer le port local et creer le socle", "SectionGuide"),
    p("Si Docker Compose a ete utilise sur ce PC, liberer le port 8443. Ensuite, le script cree kind, charge les images VeloCite dans les noeuds, installe les outils du cluster et cree dev."),
    code("cd app\ndocker compose down\ncd ..\n./scripts/up.ps1 -Env dev\nkubectl config use-context kind-velocite\nkubectl get nodes"),
    p("Resultat attendu : les noeuds velocite-control-plane et velocite-worker sont Ready. Le script peut prendre plusieurs minutes lors du premier lancement.", "SmallGuide"),
])

story.extend([
    p("4. Creer l'environnement de production", "SectionGuide"),
    p("Le workspace OpenTofu doit correspondre a la valeur env du fichier prod.tfvars. Ces commandes creent le namespace, les quotas, les politiques reseau et les secrets de prod."),
    code("tofu -chdir=infra/20-env workspace select -or-create prod\ntofu -chdir=infra/20-env plan -var-file=envs/prod.tfvars\ntofu -chdir=infra/20-env apply -var-file=envs/prod.tfvars\ntofu -chdir=infra/20-env workspace select dev"),
    p("Lire le plan avant de confirmer l'apply. Le retour final au workspace dev evite une commande OpenTofu future lancee par erreur contre prod.", "SmallGuide"),
    p("5. Deployer les applications", "SectionGuide"),
    p("Les deux overlays utilisent les manifests communs et la version API 2.2.0. En prod, l'API est geree par un HPA (2 a 4 pods), tandis que nginx et ingest ont deux replicas."),
    p("Dev :", "SmallGuide"),
    code("kubectl kustomize deploy/overlays/dev > rendu-dev.yaml\nkubectl apply -k deploy/overlays/dev\nkubectl -n velocite-dev rollout status deployment/api --timeout=180s\nkubectl -n velocite-dev wait --for=condition=complete job/initialisation --timeout=180s"),
    p("Prod :", "SmallGuide"),
    code("kubectl kustomize deploy/overlays/prod > rendu-prod.yaml\nkubectl apply -k deploy/overlays/prod\nkubectl -n velocite-prod rollout status deployment/api --timeout=180s\nkubectl -n velocite-prod wait --for=condition=complete job/initialisation --timeout=180s"),
    p("Les fichiers rendu-dev.yaml et rendu-prod.yaml sont des fichiers de controle local : ne pas les ajouter a Git.", "SmallGuide"),
])

story.append(PageBreak())
story.extend([
    p("6. Verifier que les deux environnements sont prets", "SectionGuide"),
    code("kubectl -n velocite-dev get pods\nkubectl -n velocite-prod get pods,hpa,pdb\n\n./scripts/smoke.ps1 -Env dev\n./scripts/smoke.ps1 -Env prod\n\nkubectl diff -k deploy/overlays/dev\nkubectl diff -k deploy/overlays/prod"),
    p("Resultats attendus", "SectionGuide"),
])
rows = [
    [p("Controle", "SmallGuide"), p("Attendu", "SmallGuide")],
    [p("Dev", "SmallGuide"), p("API 2.2.0, environnement dev, smoke test entierement vert.", "SmallGuide")],
    [p("Prod", "SmallGuide"), p("API 2.2.0, environnement prod, smoke test entierement vert.", "SmallGuide")],
    [p("HPA prod", "SmallGuide"), p("api, minimum 2 et maximum 4 replicas.", "SmallGuide")],
    [p("PDB prod", "SmallGuide"), p("api, ingest et nginx presents, minAvailable = 1.", "SmallGuide")],
    [p("Diffs", "SmallGuide"), p("Aucune sortie : le cluster correspond aux manifests Git.", "SmallGuide")],
]
table = Table(rows, colWidths=[4.1 * cm, 12.2 * cm], repeatRows=1)
table.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#12355B")),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("GRID", (0, 0), (-1, -1), 0.35, colors.HexColor("#C8D8E3")),
    ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F7FAFC")),
    ("LEFTPADDING", (0, 0), (-1, -1), 7),
    ("RIGHTPADDING", (0, 0), (-1, -1), 7),
    ("TOPPADDING", (0, 0), (-1, -1), 5),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
]))
story.append(table)
story.append(Spacer(1, 10))
story.extend([
    p("En cas de blocage", "SectionGuide"),
    p("Si une commande tofu demande la phrase de state, redefinir TF_VAR_phrase_etat dans le terminal. Si une image est introuvable, relancer ./scripts/charger-images.ps1. Si un pod ne devient pas pret, lire d'abord :"),
    code("kubectl -n velocite-dev get pods\nkubectl -n velocite-dev describe pod NOM_DU_POD\nkubectl -n velocite-dev logs NOM_DU_POD --previous"),
    p("Pour une mise a jour qui echoue, le service doit rester disponible grace au rollout progressif. Revenir immediatement en arriere avec :", "SmallGuide"),
    code("kubectl -n velocite-dev rollout undo deployment/api"),
    p("Puis corriger le depot avant de refaire kubectl apply. Ne pas utiliser kubectl edit : la correction serait perdue au prochain apply.", "WarningGuide"),
])

doc.build(story, onFirstPage=header, onLaterPages=header)
print(OUTPUT)
