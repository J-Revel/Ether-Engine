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
	
layout system : input handling is deferred because the placement of the widgets is handled once the container is closed, ie removed from the stack (pop_layout)
computes the preferred size at this moment, from the preferred size of the children that have been computed before
the layout is just a function called to place the elements and compute the preferred sizes

Types of layout : most directly allocate a sub rect to their children, some adapt to their sizes => main difference : not the same one that decides of the size of the child 
 sometimes mixed ? 
=> 
 	- children get a pos and size allocated by the layout (0 means the parent doesn't care)
	- when they are handled, they emit a preferred size that can be used or not by the layout
	- the layout places the children properly, and can use the preferred sizes

