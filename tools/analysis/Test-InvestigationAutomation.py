"""Tests of inference boundaries, deterministic refresh and interleaved log replay."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,HERE/file)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
reader=module('reader','Read-Investigation.py')
truth=module('truth','Truth-Investigation.py')
runner=module('runner','Run-Investigation.py')
ports=module('ports','Extract-USB4PortStatus.py')


class Milestones(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model=json.loads((reader.ROOT/'evidence/investigation-logic.json').read_text())
        cls.view=reader.Investigation(reader.ROOT,json.loads(reader.MODEL.read_text(encoding='utf-8')))
        cls.result=truth.solve(cls.model,cls.view,reader.pointer)

    def test_final_absence_does_not_become_never_entered_or_linked(self):
        case=self.result['cases'][0]
        self.assertIsNone(case['observed_facts']['E'])
        self.assertIsNone(case['observed_facts']['L'])
        self.assertIsNone(case['observed_facts']['R'])
        self.assertEqual(len(case['frontier_counts']),4)
        self.assertTrue(any(w['L'] and not w['F'] for w in case['abstract_worlds']))
        self.assertTrue(any(w['R'] and not w['F'] for w in case['abstract_worlds']))

    def test_control_completion_is_independent_of_link_milestones(self):
        vars=[v['id'] for v in self.model['variables']]
        a=truth.enumerate_worlds(vars,self.model['implications'],{'F':False,'C':True})
        b=truth.enumerate_worlds(vars,self.model['implications'],{'F':False,'C':False})
        project=lambda ws:{tuple(w[k] for k in vars if k!='C') for w in ws}
        self.assertEqual(project(a),project(b))

    def test_operational_control_implies_milestones_but_not_wire_capture(self):
        case=self.result['cases'][1]
        self.assertIsNone(case['observed_facts']['E'])
        self.assertTrue(case['model_implied_not_measured']['E'])
        self.assertTrue(case['model_implied_not_measured']['L'])
        self.assertEqual(set(case['frontier_counts']),{'ROUTER_PRESENT'})
        self.assertTrue(any(w['X'] and w['F'] for w in case['abstract_worlds']))

    def test_source_quality_failure_leaves_control_unknown(self):
        view=copy.copy(self.view);view.values=copy.deepcopy(self.view.values)
        view.values['ASUS-COMPLETIONS']=9
        facts,_=truth.facts_for(self.model['cases'][0],[v['id'] for v in self.model['variables']],view)
        self.assertIsNone(facts['C'])

    def test_missing_fact_and_wrong_case_stop(self):
        case=copy.deepcopy(self.model['cases'][0]);del case['facts']['E']
        with self.assertRaises(ValueError):truth.facts_for(case,[v['id'] for v in self.model['variables']],self.view)
        case=copy.deepcopy(self.model['cases'][0]);case['id']='DELL-CONTROL'
        with self.assertRaisesRegex(ValueError,'case mismatch'):truth.facts_for(case,[v['id'] for v in self.model['variables']],self.view)

    def test_conflicting_facts_are_not_a_hardware_impossibility_claim(self):
        worlds=truth.enumerate_worlds([v['id'] for v in self.model['variables']],self.model['implications'],{'F':True,'E':False})
        self.assertEqual(worlds,[])

    def test_ideal_observation_ranking_does_not_acquire_a_sample(self):
        first=self.result['cases'][0]['ideal_observations'][0]
        self.assertEqual((first['variable'],first['worst_remaining_frontiers']),('L',2))
        self.assertIn('negative current sample',first['caveat'])

    def test_pipeline_is_deterministic_and_committed_outputs_match(self):
        outputs,a=runner.prepare();outputs2,b=runner.prepare()
        self.assertEqual(outputs,outputs2);self.assertEqual(a,b)
        for path,text in outputs.items():self.assertEqual((reader.ROOT/path).read_bytes(),text.encode('utf-8'))


class PortResponses(unittest.TestCase):
    profile=dict(controller='TEST',adapter=2,router_offset=0xd2)
    def lines(self):
        return [
          '[0]0::11/01/2026-00:00:00.0000000 [usb4drd]([TEST]::0:0:0:0:0:0::DFP_2)Transition (Call): ReadingRouterDetected ---(_noevent_)---> WaitingForCompletion',
          '[0]0::11/01/2026-00:00:00.0000010 [usb4hrd][TEST][0x1]Read Response - RS: 0 0 0 0 0 0 , USB4AdapterConfigurationSpace, Adapter: 2, DW offset: 0xD2, DW length: 1, SN: 0',
          '[0]0::11/01/2026-00:00:00.0000020 [usb4hrd][TEST][0x2]Read Response - RS: 0 0 0 0 0 0 , USB4AdapterConfigurationSpace, Adapter: 3, DW offset: 0xD2, DW length: 1, SN: 0',
          '[0]0::11/01/2026-00:00:00.0000030 [usb4hrd][TEST][0x2]DWORD[0]: 0x00002000',
          '[0]0::11/01/2026-00:00:00.0000040 [usb4hrd][TEST][0x1]DWORD[0]: 0x00010400',
          '[0]0::11/01/2026-00:00:00.0000050 [usb4drd]([TEST]::0:0:0:0:0:0::DFP_2)Transition (External): IsRouterDetectedSet ---(No)---> WaitingForRouterConnect']

    def test_interleaved_other_adapter_payload_does_not_replace_target(self):
        result=ports.parse(self.lines(),self.profile)
        self.assertEqual(result['branches'][0]['sample']['value'],0x10400)
        self.assertEqual(result['branches'][0]['result'],'No')
        self.assertNotIn('0x1',json.dumps(result))

    def test_missing_wrong_index_or_duplicate_payload_stops(self):
        lines=self.lines();del lines[4]
        with self.assertRaises(ValueError):ports.parse(lines,self.profile)
        lines=self.lines();lines[4]=lines[4].replace('DWORD[0]','DWORD[1]')
        with self.assertRaises(ValueError):ports.parse(lines,self.profile)
        lines=self.lines();lines.insert(2,lines[1])
        with self.assertRaisesRegex(ValueError,'Incomplete response'):ports.parse(lines,self.profile)

    def test_ambiguous_read_phase_or_wrong_root_is_not_guessed(self):
        lines=self.lines();lines[5:5]=[lines[1],lines[4]]
        with self.assertRaisesRegex(ValueError,'exactly one'):ports.parse(lines,self.profile)
        lines=self.lines();lines[1]=lines[1].replace('RS: 0 0 0 0 0 0','RS: 1 0 0 0 0 0')
        with self.assertRaises(ValueError):ports.parse(lines,self.profile)

    def test_branch_disagreement_and_unpinned_file_stop(self):
        lines=self.lines();lines[-1]=lines[-1].replace('(No)','(Yes)')
        with self.assertRaisesRegex(ValueError,'disagree'):ports.parse(lines,self.profile)
        with tempfile.TemporaryDirectory(prefix='usb4-offline-test-') as d:
            path=Path(d)/'input.txt';path.write_text('synthetic, not a capture')
            with self.assertRaisesRegex(ValueError,'hash mismatch'):ports.extract(path,'ASUS-DEEP')

    def test_published_real_replays_include_clear_and_set_native_bits(self):
        data=json.loads((reader.ROOT/'evidence/router-detection-branch.json').read_text())
        asus,dell=data['cases']
        self.assertEqual([b['result'] for b in asus['branches'] if b['kind']=='router_detected'],['No','No'])
        self.assertEqual([b['result'] for b in dell['branches'] if b['kind']=='router_detected'],['Yes'])
        self.assertEqual([b['result'] for b in dell['branches'] if b['kind']=='plugged'],['No'])
        for case in (asus,dell):
            for branch in case['branches']:
                self.assertEqual(bool(branch['sample']['value'] & int(branch['mask_hex'],16)),branch['result']=='Yes')


if __name__=='__main__':unittest.main(verbosity=2)
