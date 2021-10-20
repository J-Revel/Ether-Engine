# Gestion du padding :

Pb : taille et positionnement pas connus au moment du positionnement des widgets enfants => si la taille du parent dépend du contenu mais que le contenu essaye de prendre toute la place, problème

Exemple de layout non géré actuellement :
Horizontal layout dont certains éléments doivent avoir une taille adaptée au contenu, et d'autres sont fixes.

-> push_layout()
	-> element 1 taille fixe
	-> filler (taille variable)
	-> element 2 taille variable
	-> element 3
-> pop_layout()
On ne peut connaître la position finale des éléments qu'au moment du pop_layout => besoin de commandes dont la position finale n'est pas encore calculée

*A garder en tête : ces layouts complexes peuvent être imbriqués*

-> notion de commandes imbriquées ? positions/tailles relatives à une autre commande
	-> positions absolues calculées au moment de la transformation en GPU_Commands

/!\ Pas vraiment commandes imbriquées, les layouts n'ont pas forcément de commande attachée
-> plutôt utiliser les layouts ou les elements ? => les deux devraient être utilisables en même temps
-> utiliser les UI_Elements ? => arbre de UI_Elements, le Rect est local au parent
-> rect local à un autre rect = pos size ou padding ? => potentiellement les deux, union

Pb : on perd la simplicité d'utiliser un rect pour chaque élément 
=> Tout doit être fait à partir d'un UI Element ?
=> Besoin de garder en mémoire la stack d'UI Elements

Par contre plus besoin de récupérer les rects de layouts => la taille suffit
Content Size Fitter => calcul de la taille uniquement, via le max x et y des enfants

à checker : propagation des content size fitters dans le use_rect_in_layout => pas besoin de propagation ?
penser à faire des pop_element partout

Idée : 
	- le content size fitter n'est qu'un type de layout auto ?
	- le layout de base aussi (horizontal/vertical layout) => de base tout est mis au même endroit, le layout déplace les éléments a posteriori
	=> pb : position pas connue au moment où on veut gérer les events
	
layout system : input handling is deferred because the placement of the widgets is handled once the container is closed, ie removed from the stack (pop_layout)
computes the preferred size at this moment, from the preferred size of the children that have been computed before
the layout is just a function called to place the elements and compute the preferred sizes

Types of layout : most directly allocate a sub rect to their children, some adapt to their sizes => main difference : not the same one that decides of the size of the child 
 sometimes mixed ? 
=> 
 	- children get a pos and size allocated by the layout (0 means the parent doesn't care)
	- when they are handled, they emit a preferred size that can be used or not by the layout
	- the layout places the children properly, and can use the preferred sizes

