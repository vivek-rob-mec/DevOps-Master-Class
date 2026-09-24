import importlib.util,pathlib,tempfile,unittest
path=pathlib.Path(__file__).parents[1]/"scripts"/"verify_action_pins.py";spec=importlib.util.spec_from_file_location("pins",path);pins=importlib.util.module_from_spec(spec);spec.loader.exec_module(pins)
class PinPolicyTests(unittest.TestCase):
 def test_accepts_sha(self):self.assertEqual([],pins.invalid_references("uses: actions/checkout@"+"a"*40))
 def test_rejects_tag(self):self.assertEqual([(1,"actions/checkout@v4")],pins.invalid_references("uses: actions/checkout@v4"))
 def test_accepts_local_action(self):self.assertEqual([],pins.invalid_references("uses: ./actions/build"))
if __name__=="__main__":unittest.main()
