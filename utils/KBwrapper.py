from utils.general import decode
import numpy as np
# import os
# import sys
# import string
from nle import nethack
from pyswip import Prolog
from utils import exceptions


class KBwrapper():
    # It is here on purpose: it is a class variable ("knowledge" shared
    # among all instances of the class). I think it is more proper.
    # changes to this reflect to all KBwrapper objects 
    # (most probabily we'll have only one, so who cares...)
    _categories = {
        'enemy': ['kobold', 'giant mummy', 'goblin'],
        'comestible': ['apple', 'carrot', 'food ration'],
        'weapon': ['sword', 'lance', 'shield', 'dagger'],
        'applicable' : ['saddle'],
    }

    def __init__(self):
        self._kb = Prolog()
        self._kb.consult('KBS/kb.pl')

    def queryDirectly(self, sentence:str):
        '''For rapid-test purposes only.
        The function queries the kb for the sentence in input.
        The query method is applied directly to sentence.
        '''
        return list(self._kb.query(sentence))

    # this is very experimental
    def query_for_action(self):
        try:
            action = list(self._kb.query("action(X)"))[0]
            action = action['X']
        except Exception as e:
            print(e)
            action = None
        return action
    
    def query_for_interrupt(self, current_subtask: str) -> bool:
        try:
            interrupt = bool(list(self._kb.query(f"interrupt({current_subtask})")))
        except Exception as e:
            print(e)
            interrupt = False
        return interrupt
    
    #def assert_performed_action(self):
        # Q: quindi devo dire alla KB l'azione che ho fatto?
        # problema: se ogni azione richiede un formato specifico, in questa funzione
        # c'è un'esplosione di if (ovvero di cose da dire). Non è più chiaro ed 
        # elegante dire la cosa giusta al momento giusto?

    # the idea is that the position of an element should be returned by 
    # the KB
    # TODO: deal with multiple items in the map (e.g. two carrots).See also 
    # comment on the _element_position() function
    def get_element_position(self, element:str):
        try:
            pos_query = list(self._kb.query(f'position({element},_,Row,Col)'))[0]
            return (pos_query['Row'], pos_query['Col'])
        except IndexError:
            raise exceptions.ElemNotFoundException\
                (f'query for the position of {element} unsuccessful. '
                'Maybe they are not in the environment?')
        
    def _get_key(self,value, dictionary):
        for key, values in dictionary.items():
            if value in values:
                return key
        return None   
    
    def retract_element_position(self, element:str, *args):
        if(len(args) == 0):
            x, y = '_','_'
        else:
            x, y = args

        category = self._get_key(element, self._categories)
        if category is None:
            self._kb.retractall(f'position({element},{element},{x},{y})')
        else:
            self._kb.retractall(f'position({category},{element},{x},{y})')

    def assert_element_position(self,element:str, x:int, y:int):
        category = self._get_key(element, self._categories)
        if category is None:
            self._kb.asserta(f'position({element},{element},{x},{y})')
        else:
            self._kb.asserta(f'position({category},{element},{x},{y})')

    def get_rideable_steeds(self):
        return self._kb.query("rideable(X)")
    
    def get_steed_tameness(self, steed):
        return self._kb.query(f"steed_tameness({steed}, X)")[0]['X']
    
    def is_slippery(self):
        return self._kb.query("slippery")[0]

    def update_health(self, health:int):
        self._kb.retractall('health(_)')
        self._kb.asserta(f'health({health})')
